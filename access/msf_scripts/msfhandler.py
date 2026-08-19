#!/usr/bin/env python3

import argparse

def generate_resource_script(lhost, lport, architecture, payload_type, os_type, protocol):
    """
    Generates the msfconsole resource script as a string.

    Args:
        lhost (str): Local host IP address.
        lport (int): Local port number.
        architecture (str): Architecture (e.g., x86, x64).
        payload_type (str): Payload type (e.g., meterpreter, shell).
        os_type (str): Operating system type (e.g., windows, linux).
        protocol (str): Protocol type (e.g., tcp, http, https).

    Returns:
        str: The resource script as a string.
    """
    payload = f"{os_type}/{architecture}/{payload_type}/reverse_{protocol}"
    if architecture == 'x86': 
        payload = f"{os_type}/{payload_type}/reverse_{protocol}"

    resource_script = (
        f"'setg LHOST {lhost};"
        f"setg LPORT {lport};"
        f"setg PAYLOAD {payload};"
        "use exploit/multi/handler;'"
    )
    return resource_script

def main():
    parser = argparse.ArgumentParser(description="Generate and configure msfconsole payloads.")
    parser.add_argument("lhost", help="Local host IP address")
    parser.add_argument("lport", type=int, help="Local port number")
    parser.add_argument("-a", "--architecture", default="x86", help="Architecture (default: x86)")
    parser.add_argument("-t", "--type", default="meterpreter", choices=["meterpreter", "shell"], help="Payload type (default: meterpreter)")
    parser.add_argument("--os", default="windows", choices=["windows", "linux"], help="Operating system type (default: windows)")
    parser.add_argument("--protocol", default="tcp", choices=["tcp", "http", "https"], help="Protocol type (default: tcp)")

    args = parser.parse_args()

    # Generate the resource script as a string
    resource_script = generate_resource_script(args.lhost, args.lport, args.architecture, args.type, args.os, args.protocol)

    # Print the command rather than running it, so it can be reviewed, edited
    # and pasted. (subprocess was imported for a launch that was never
    # implemented.)
    print("Run:")
    print(' '.join(["msfconsole", "-q", "-x", resource_script]))

if __name__ == "__main__":
    main()
