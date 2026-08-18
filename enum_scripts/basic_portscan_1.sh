#!/bin/bash
timeout 0.1 bash -c "echo >/dev/tcp/10.11.1.251/23" && echo "open" || echo "closed"
