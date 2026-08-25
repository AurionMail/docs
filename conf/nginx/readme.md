## Aurion NGIX
Each files provided here listen on http. Each time, you must run
```
sudo ln -s /etc/nginx/sites-available/SUB.DOMAIN /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx -d SUB.DOMAIN
```
to active https. As a reminder, https is mandatory by Aurion, without it, it wont work.
## Cryptpad
To activate https for Cryptpad (pad.), don't folllow the precendet instructions. Cryptpad need a certificat that cover its two domains at same time.
- Comment 443 of the config file. Without commenting, nginx will produce error when requesting certificates.
- sudo certbot --nginx -d pad.DOMAIN_REPLACE_ME -d sand.DOMAIN_REPLACE_ME
- sudo openssl dhparam -out /etc/nginx/dhparam.pem 4096 (can take some times... (5min on my test server))
- Then uncomment part 443

## Core API
If you want to activate the web key server to make your keys discoverable, you need two domain for the core API. If you don't want, ignore the following instructions :
- sudo certbot --nginx -d api.DOMAIN_REPLACE_ME -d openpgpkeys.DOMAIN_REPLACE_ME