- Make ansible roles (more) idempotent.
- Figure out a (safe) way for revert-home.sh to work even when /home is busy
  (because of background processes running for labuser). Killing the processes
  doesn't really work because things (e.g. XFCE) start failing if we do so.
- LDAP authentication for user login.
