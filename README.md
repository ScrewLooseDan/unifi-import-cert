
# unifi-import-cert

A simple script to update UniFi Controller certs.

Much of this script came from two places:
https://util.wifi.gl/unifi-import-cert.sh
Author: Frank Gabriel, 15.09.2018
Credits Kalle Lilja and others
&
https://github.com/stevejenkins/unifi-linux-utils
UniFi Controller SSL Certificate Import Script for Unix/Linux Systems
by Steve Jenkins <http://www.stevejenkins.com/>

Heavily modified by Screw Loose Dan 10/16/2018

# Usage

1. Copy this file somewhere logical (/usr/local/bin/ ?)
   and ensure it is excecutable by root (chmod 700)
2. Verify that you have valid certificates.
3. Update the settings as necassary below.
4. Manually run the script once to make sure it works.
5. Verify that the UniFi Controller is now using the expected certs.
6. Put a symlink in /etc/letsencrypt/renewal-hooks/deploy/ to script
    (something like ln -s /usr/local/bin/usr/local/bin/unifi-import-cert.sh)
7. Probably should do a dry run (certbot renew --dry-run) to ensure
    that the deploy hooks are seen (but they aren't run).
8. Have some coffee and wait for your certs to renew and verify everything works!

# Dependencies

An attempt has been made to keep this fairly portable and as such,
 the binaries required for this should be on most linux systems.
A mail command ('mail') needs to be functioning in order to reeceive emails.
