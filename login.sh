<<-EOF
  #!/bin/bash
  mkdir /var/www/html/login
    echo "<h1>This is the site page</h1>" > /var/www/html/login/index.html
    service httpd start
    chkconfig httpd on
EOF