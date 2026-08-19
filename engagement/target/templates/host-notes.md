# Notes: {{HOST}}

- Host: {{HOST}}
- IP: {{IP}}
- URL: {{URL}}
- Lab: {{LAB}}
- Created: {{DATE}}

<!-- Managed by `target`. Sections 1-4 are appended to by `target -F/-A/-H/-X`.
     Keep the `## N.` headings intact or the append commands cannot find them.
     Everything else in this file is yours to edit. Template lives at
     target/templates/host-notes.md. -->

```
================================================================================
     G A T E  --  DO NOT EXPLOIT UNTIL SECTION 2 (ANOMALIES) IS POPULATED
================================================================================
  No exploit. No searchsploit. No metasploit module. No "let me just try this".

  You have not earned an exploit until you can name one thing on this box that
  is NOT how it ships by default. Section 2 empty means enumeration is not
  finished -- it does not mean the box is hard.

  Rabbit holes are expensive. Re-reading your own notes is free.
================================================================================
```

## 0. Rules — tick these before you write anything in section 3

- [ ] Full TCP range first: `nmap -p- -T4 --open {{IP}}` BEFORE any `-sCV`. Top-1000 misses roughly one box in three, and the port you skipped is the box.
- [ ] Then targeted versions on only what that found: `nmap -sCV -p<ports> {{IP}}`. Every version string goes into section 1 verbatim.
- [ ] UDP top 200: `nmap -sU --top-ports 200 {{IP}}`.
- [ ] Every hostname seen ANYWHERE — redirect, TLS cert SAN, HTML source, service banner, error page — goes into `/etc/hosts` immediately, and is then vhost-fuzzed: `ffuf -H "Host: FUZZ.<domain>" -u http://{{IP}} -fs <baseline>`. Missed vhosts are the single most common easy-box failure.
- [ ] Read the page source and EVERY JS file by hand BEFORE running a directory brute force. Comments, endpoints, versions, usernames, API keys.
- [ ] Re-enumerate after EVERY credential found. New creds invalidate all previous enumeration — retry every service, every share, every login, as the new user. New creds are a new enumeration pass, not a shortcut to escalation.
- [ ] Every version number in section 1 → `searchsploit` AND a web search, before anything goes into section 3.
- [ ] Curl anything that responds on a non-standard port. HTTP hides on odd ports.
- [ ] Section 2 contains at least one entry that is genuinely not a default install.

Full per-service checklist: `notes/pentest_enumeration_checklist.md`

## 1. Facts

> Verbatim only. What the box literally told you. No interpretation, no conclusions.
> Ports, versions, hostnames, usernames, emails, paths, tech stack, odd HTTP headers.
>
> Append: `target -F "80/tcp nginx 1.18.0 (Ubuntu)"`

## 2. Anomalies

> Deviations from a default install: things someone deliberately changed, added,
> misconfigured, or left behind. A stock Ubuntu nginx page is not an anomaly.
> A stock nginx page serving `/backup/` is.
>
> If you cannot fill this in, you are not finished with section 1.
>
> Append: `target -A "..."`

## 3. Hypotheses

> One per anomaly: anomaly -> candidate attack path -> what would prove or kill it.
> Nothing goes here that is not traceable to a line in section 2.
>
> Append: `target -H "..."`

## 4. Tried / failed

> What you tried, and WHY it failed. "Didn't work" is not a reason.
> The reason is what stops you burning an hour repeating it at hour six.
>
> Append: `target -X "..."`
