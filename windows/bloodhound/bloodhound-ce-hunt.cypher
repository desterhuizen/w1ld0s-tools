// BloodHound CE — high-signal query pack
// ======================================
// Read by bh-hunt, which speaks the neo4j HTTP transaction API directly. Also
// runnable by hand: paste a query into the CE "Cypher" tab, or feed the file to
// legacy/bh-hunt.sh if you have cypher-shell.
//
// Format, and the runner depends on it:
//   // name: <label>          introduces a query
//   // severity: <level>      optional, one of critical high medium info
//   <cypher>                  one or more lines, terminated by a semicolon
// No "//" inside a query body — a comment line ends the body.
//
// Two conventions used throughout:
//   Tier Zero   coalesce(n.system_tags,'') CONTAINS 'admin_tier_0'
//   owned       n.owned = true  OR  system_tags CONTAINS 'owned'
// The first is what CE stamps on its Admin Tier Zero asset group. The second
// covers both marking sources: bh-hunt --owned sets the property, the CE UI's
// "Mark as Owned" adds the tag. Neither is required for the pack to run, but
// the owned-relative queries return nothing until one of them is set.
//
// Well-known RIDs used below: -501 Guest, -512 Domain Admins, -513 Domain
// Users, -514 Domain Guests, -515 Domain Computers, -516 Domain Controllers,
// -518 Schema Admins, -519 Enterprise Admins, -544 Administrators, -548
// Account Operators, -549 Server Operators, -550 Print Operators, -551 Backup
// Operators. S-1-5-11 Authenticated Users, S-1-1-0 Everyone.

// ===== ORIENTATION =====

// name: Domain summary
// severity: info
MATCH (d:Domain)
RETURN d.name AS domain, d.functionallevel AS functional_level,
       d.machineaccountquota AS machine_account_quota;

// name: Enabled object counts
// severity: info
MATCH (u:User) WHERE u.enabled = true
WITH count(u) AS enabled_users
MATCH (c:Computer) WHERE c.enabled = true
WITH enabled_users, count(c) AS enabled_computers
MATCH (g:Group)
RETURN enabled_users, enabled_computers, count(g) AS groups;

// name: Domain controllers
// severity: info
MATCH (c:Computer)-[:MemberOf*1..3]->(g:Group)
WHERE g.objectid ENDS WITH '-516'
RETURN DISTINCT c.name AS domain_controller, c.operatingsystem AS os
ORDER BY domain_controller;

// name: Tier Zero (high-value) principals
// severity: info
MATCH (n) WHERE coalesce(n.system_tags,'') CONTAINS 'admin_tier_0'
RETURN labels(n)[0] AS type, n.name AS principal
ORDER BY type, principal;

// name: Currently owned principals
// severity: info
MATCH (n) WHERE n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned'
RETURN labels(n)[0] AS type, n.name AS owned
ORDER BY type, owned;

// name: Domain trusts
// severity: medium
MATCH (a:Domain)-[r:TrustedBy]->(b:Domain)
RETURN a.name AS domain, b.name AS trusted_by, r.trusttype AS trust_type,
       r.transitive AS transitive, r.sidfiltering AS sid_filtering;

// ===== ATTACK PATHS FROM OWNED =====

// name: Shortest path owned -> Domain Admins
// severity: critical
MATCH (n) WHERE n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned'
MATCH (g:Group) WHERE g.objectid ENDS WITH '-512'
MATCH p = shortestPath((n)-[*1..8]->(g))
RETURN [x IN nodes(p) | x.name] AS path
LIMIT 25;

// name: Shortest path owned -> any Tier Zero
// severity: critical
MATCH (n) WHERE n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned'
MATCH (m) WHERE coalesce(m.system_tags,'') CONTAINS 'admin_tier_0' AND n <> m
MATCH p = shortestPath((n)-[*1..8]->(m))
RETURN [x IN nodes(p) | x.name] AS path
LIMIT 25;

// name: First-degree ACL control from owned (immediate wins)
// severity: critical
MATCH (n)-[r]->(m)
WHERE (n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned') AND r.isacl = true
RETURN n.name AS controller, type(r) AS edge, labels(m)[0] AS target_type,
       m.name AS target
ORDER BY controller;

// name: Dangerous ACLs from owned (spidered, multi-hop)
// severity: critical
MATCH (n) WHERE n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned'
MATCH p = shortestPath((n)-[:GenericAll|GenericWrite|WriteDacl|WriteOwner|Owns|AllExtendedRights|ForceChangePassword|AddMember|AddKeyCredentialLink|AddSelf|WriteAccountRestrictions|WriteSPN|AddAllowedToAct*1..6]->(m))
WHERE n <> m
RETURN [x IN nodes(p) | x.name] AS path
LIMIT 40;

// name: Local admin from owned, including group-derived
// severity: critical
MATCH (n) WHERE n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned'
MATCH (n)-[:MemberOf*0..5]->()-[:AdminTo]->(c:Computer)
RETURN DISTINCT n.name AS owned, c.name AS admin_on
ORDER BY owned, admin_on;

// name: Remote execution rights from owned (RDP, WinRM, DCOM, SQL)
// severity: high
MATCH (n) WHERE n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned'
MATCH (n)-[:MemberOf*0..5]->()-[r:CanRDP|CanPSRemote|ExecuteDCOM|SQLAdmin]->(c:Computer)
RETURN DISTINCT n.name AS owned, type(r) AS via, c.name AS target
ORDER BY owned, target;

// name: Shadow Credentials targets from owned (AddKeyCredentialLink)
// severity: critical
MATCH (n)-[:AddKeyCredentialLink]->(m)
WHERE n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned'
RETURN n.name AS controller, labels(m)[0] AS target_type, m.name AS target;

// name: GPO control from owned
// severity: critical
MATCH (n)-[r]->(g:GPO)
WHERE n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned'
RETURN n.name AS controller, type(r) AS edge, g.name AS gpo;

// ===== EVERYONE CAN =====

// name: Dangerous ACLs held by Domain Users / Authenticated Users / Everyone
// severity: critical
MATCH (g:Group)-[r]->(m)
WHERE r.isacl = true
  AND any(s IN ['-513','-514','-515','S-1-5-11','S-1-1-0'] WHERE g.objectid ENDS WITH s)
RETURN g.name AS everyone_group, type(r) AS edge, labels(m)[0] AS target_type,
       m.name AS target
ORDER BY everyone_group, edge;

// name: Computers where Domain Users / Everyone are local admin
// severity: critical
MATCH (g:Group)-[:AdminTo]->(c:Computer)
WHERE any(s IN ['-513','-514','-515','S-1-5-11','S-1-1-0'] WHERE g.objectid ENDS WITH s)
RETURN g.name AS everyone_group, c.name AS admin_on
ORDER BY admin_on;

// name: MachineAccountQuota allows adding computers
// severity: high
MATCH (d:Domain) WHERE coalesce(d.machineaccountquota, 0) > 0
RETURN d.name AS domain, d.machineaccountquota AS maq;

// ===== EFFECTIVE PRIVILEGE =====

// name: Effective Domain Admins (transitive membership)
// severity: high
MATCH (u:User)-[:MemberOf*1..5]->(g:Group)
WHERE g.objectid ENDS WITH '-512' OR g.objectid ENDS WITH '-519'
   OR g.objectid ENDS WITH '-518'
RETURN DISTINCT u.name AS effective_admin, g.name AS via_group, u.enabled AS enabled
ORDER BY via_group, effective_admin;

// name: Members of Tier Zero adjacent operator groups
// severity: high
MATCH (n)-[:MemberOf*1..5]->(g:Group)
WHERE any(s IN ['-544','-548','-549','-550','-551'] WHERE g.objectid ENDS WITH s)
   OR g.name STARTS WITH 'DNSADMINS@'
RETURN g.name AS operator_group, collect(DISTINCT n.name)[0..25] AS members;

// name: admincount set but not Tier Zero (stale adminSDHolder)
// severity: medium
MATCH (u:User)
WHERE u.admincount = true AND NOT coalesce(u.system_tags,'') CONTAINS 'admin_tier_0'
RETURN u.name AS account, u.enabled AS enabled
ORDER BY account;

// name: Most powerful accounts by local admin count
// severity: medium
MATCH (u:User)-[:MemberOf*0..5]->()-[:AdminTo]->(c:Computer)
RETURN u.name AS account, count(DISTINCT c) AS admin_on_count
ORDER BY admin_on_count DESC
LIMIT 15;

// name: Outbound dangerous ACL control from any user (owned or not)
// severity: high
MATCH (u:User)-[r]->(m)
WHERE r.isacl = true
  AND type(r) IN ['GenericAll','GenericWrite','WriteDacl','WriteOwner','Owns',
                  'AllExtendedRights','ForceChangePassword','AddMember',
                  'AddKeyCredentialLink','AddSelf','WriteAccountRestrictions',
                  'WriteSPN','AddAllowedToAct']
RETURN u.name AS controller, type(r) AS edge, labels(m)[0] AS target_type,
       m.name AS target
ORDER BY controller, edge;

// name: Users with the most outbound control (fan-out ranking)
// severity: medium
MATCH (u:User)-[r]->(m)
WHERE r.isacl = true AND u <> m
RETURN u.name AS controller, count(DISTINCT m) AS controls_count,
       collect(DISTINCT type(r))[0..8] AS edge_types
ORDER BY controls_count DESC
LIMIT 15;

// ===== KERBEROS ROASTING =====

// name: Kerberoastable users (enabled)
// severity: high
MATCH (u:User) WHERE u.hasspn = true AND u.enabled = true
RETURN u.name AS account, u.admincount AS admincount,
       CASE WHEN coalesce(u.pwdlastset, 0) > 0
            THEN (datetime().epochSeconds - u.pwdlastset) / 86400
            ELSE null END AS pwd_age_days,
       u.serviceprincipalnames AS spns
ORDER BY pwd_age_days DESC;

// name: Kerberoastable WITH a path to Domain Admins
// severity: critical
MATCH (u:User) WHERE u.hasspn = true AND u.enabled = true
MATCH (g:Group) WHERE g.objectid ENDS WITH '-512'
MATCH p = shortestPath((u)-[*1..8]->(g))
RETURN DISTINCT u.name AS kerberoastable_with_da_path;

// name: Kerberoastable Tier Zero (crown jewels if crackable)
// severity: critical
MATCH (u:User)
WHERE u.hasspn = true AND coalesce(u.system_tags,'') CONTAINS 'admin_tier_0'
RETURN u.name AS account, u.enabled AS enabled;

// name: AS-REP roastable users (enabled)
// severity: high
MATCH (u:User) WHERE u.dontreqpreauth = true AND u.enabled = true
RETURN u.name AS account, u.admincount AS admincount;

// name: AS-REP roastable and privileged
// severity: critical
MATCH (u:User)
WHERE u.dontreqpreauth = true
  AND (u.admincount = true OR coalesce(u.system_tags,'') CONTAINS 'admin_tier_0')
RETURN u.name AS account, u.enabled AS enabled;

// ===== DELEGATION =====

// name: Unconstrained delegation (excluding DCs)
// severity: critical
MATCH (dc:Computer)-[:MemberOf*1..3]->(g:Group) WHERE g.objectid ENDS WITH '-516'
WITH collect(DISTINCT dc.name) AS dcs
MATCH (c:Computer) WHERE c.unconstraineddelegation = true AND NOT c.name IN dcs
RETURN c.name AS unconstrained_non_dc, c.enabled AS enabled;

// name: Constrained delegation (AllowedToDelegate)
// severity: high
MATCH (n)-[:AllowedToDelegate]->(c)
RETURN n.name AS principal, c.name AS can_delegate_to,
       n.trustedtoauth AS protocol_transition;

// name: Constrained delegation with protocol transition (S4U2Self abuse)
// severity: critical
MATCH (n)-[:AllowedToDelegate]->(c)
WHERE n.trustedtoauth = true
RETURN n.name AS principal, c.name AS can_delegate_to;

// name: Resource-based constrained delegation (AllowedToAct)
// severity: high
MATCH (n)-[:AllowedToAct]->(c)
RETURN n.name AS can_act_as, c.name AS on_computer;

// ===== DCSYNC AND DOMAIN =====

// name: Principals with DCSync on the domain
// severity: critical
MATCH (n)-[:DCSync]->(d:Domain)
RETURN n.name AS principal, d.name AS domain;

// name: Raw GetChanges + GetChangesAll pairs (DCSync the edge may have missed)
// severity: critical
MATCH (n)-[:GetChanges]->(d:Domain)
MATCH (n)-[:GetChangesAll]->(d)
RETURN DISTINCT n.name AS principal, d.name AS domain;

// name: SID history (privilege carried in an attribute)
// severity: high
MATCH (n)-[:HasSIDHistory]->(m)
RETURN n.name AS principal, labels(m)[0] AS carries_type, m.name AS carries_sid_of;

// name: Cross-domain (foreign) group membership
// severity: medium
MATCH (n)-[:MemberOf]->(g:Group)
WHERE n.domain IS NOT NULL AND g.domain IS NOT NULL AND n.domain <> g.domain
RETURN n.name AS principal, g.name AS foreign_group;

// ===== ADCS =====

// name: ADCS ESC edges (any principal -> target)
// severity: critical
MATCH (n)-[r:ADCSESC1|ADCSESC3|ADCSESC4|ADCSESC6a|ADCSESC6b|ADCSESC9a|ADCSESC9b|ADCSESC10a|ADCSESC10b|ADCSESC13]->(m)
RETURN n.name AS principal, type(r) AS esc, m.name AS target;

// name: Owned principals with a path to an ADCS ESC edge
// severity: critical
MATCH (n) WHERE n.owned = true OR coalesce(n.system_tags,'') CONTAINS 'owned'
MATCH (src)-[e]->(tgt) WHERE type(e) STARTS WITH 'ADCSESC'
MATCH p = shortestPath((n)-[*0..6]->(src))
RETURN [x IN nodes(p) | x.name] AS path_to_esc_source, type(e) AS esc,
       tgt.name AS esc_target
LIMIT 25;

// name: ESC1-shaped certificate templates (enrollee supplies subject)
// severity: critical
MATCH (t:CertTemplate)
WHERE t.enrolleesuppliessubject = true AND t.authenticationenabled = true
  AND t.requiresmanagerapproval = false AND coalesce(t.authorizedsignatures, 0) = 0
RETURN t.name AS template, t.schemaversion AS schema_version,
       t.nosecurityextension AS no_security_extension;

// name: Who can enroll in an ESC1-shaped template
// severity: critical
MATCH (n)-[:Enroll|AllExtendedRights|GenericAll]->(t:CertTemplate)
WHERE t.enrolleesuppliessubject = true AND t.authenticationenabled = true
  AND t.requiresmanagerapproval = false
RETURN n.name AS principal, t.name AS template;

// name: Enterprise CAs with EDITF_ATTRIBUTESUBJECTALTNAME2 (ESC6)
// severity: critical
MATCH (ca:EnterpriseCA) WHERE ca.isuserspecifiessanenabled = true
RETURN ca.name AS enterprise_ca;

// ===== CREDENTIAL EXPOSURE =====

// name: Credentials in object attributes (description, userPassword)
// severity: critical
MATCH (n)
WHERE (n:User OR n:Computer)
  AND (n.userpassword IS NOT NULL OR n.unixpassword IS NOT NULL
       OR n.unicodepassword IS NOT NULL OR n.sfupassword IS NOT NULL
       OR any(w IN ['pass','pwd','cred','secret']
              WHERE toLower(coalesce(n.description,'')) CONTAINS w))
RETURN labels(n)[0] AS type, n.name AS object, n.description AS description,
       coalesce(n.userpassword, n.unixpassword, n.unicodepassword,
                n.sfupassword) AS stored_password;

// name: Password not required (PASSWD_NOTREQD)
// severity: high
MATCH (u:User) WHERE u.passwordnotreqd = true AND u.enabled = true
RETURN u.name AS account, u.admincount AS admincount;

// name: Enabled accounts that have never logged on
// severity: medium
MATCH (u:User)
WHERE u.enabled = true AND coalesce(u.lastlogontimestamp, -1) <= 0
  AND coalesce(u.lastlogon, -1) <= 0
RETURN u.name AS account,
       CASE WHEN coalesce(u.whencreated, 0) > 0
            THEN toString(datetime({epochSeconds: u.whencreated}))
            ELSE 'unknown' END AS created;

// name: Privileged accounts with a password older than a year
// severity: high
MATCH (u:User)
WHERE u.enabled = true AND coalesce(u.pwdlastset, 0) > 0
  AND (u.admincount = true OR coalesce(u.system_tags,'') CONTAINS 'admin_tier_0')
  AND u.pwdlastset < datetime().epochSeconds - (365 * 86400)
RETURN u.name AS account,
       (datetime().epochSeconds - u.pwdlastset) / 86400 AS pwd_age_days
ORDER BY pwd_age_days DESC;

// name: Guest account enabled
// severity: medium
MATCH (u:User) WHERE u.enabled = true AND u.objectid ENDS WITH '-501'
RETURN u.name AS guest_account;

// ===== LATERAL MOVEMENT AND HYGIENE =====

// name: Tier Zero sessions on non-domain-controllers
// severity: critical
MATCH (dc:Computer)-[:MemberOf*1..3]->(g:Group) WHERE g.objectid ENDS WITH '-516'
WITH collect(DISTINCT dc.name) AS dcs
MATCH (c:Computer)-[:HasSession]->(u:User)
WHERE coalesce(u.system_tags,'') CONTAINS 'admin_tier_0' AND NOT c.name IN dcs
RETURN u.name AS tier0_user, c.name AS logged_on_non_dc;

// name: Any GPO under non-Tier-Zero control
// severity: high
MATCH (n)-[r]->(g:GPO)
WHERE r.isacl = true AND NOT coalesce(n.system_tags,'') CONTAINS 'admin_tier_0'
RETURN n.name AS principal, type(r) AS edge, g.name AS gpo
ORDER BY gpo;

// name: Computers without LAPS (enabled)
// severity: medium
MATCH (c:Computer) WHERE c.haslaps = false AND c.enabled = true
RETURN c.name AS computer, c.operatingsystem AS os
ORDER BY computer;

// name: Unsupported or end-of-life operating systems
// severity: high
MATCH (c:Computer)
WHERE c.enabled = true AND c.operatingsystem IS NOT NULL
  AND any(p IN ['2000','2003','2008','Windows XP','Windows Vista','Windows 7',
                'Windows 8','Server 2012']
          WHERE c.operatingsystem CONTAINS p)
RETURN c.name AS computer, c.operatingsystem AS os
ORDER BY os, computer;
