<<-EOF
  #!/bin/bash
  mkdir /var/www/html/site
    echo "<h1>This is the site page</h1>" > /var/www/html/site/index.html
    service httpd start
    chkconfig httpd on
EOF