#!/bin/bash
dnf install -y nginx
systemctl enable --now nginx

cat > /usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>Librería Tinta - Novedades</title>
</head>
<body>
  <h1>Librería Tinta - Novedades</h1>
  <p>Tu librería de barrio.</p>

  <h2>Horario</h2>
  <p>De lunes a viernes, de 9:00 a 14:00 y de 17:00 a 20:00.</p>

  <h2>Dirección</h2>
  <p>Calle de las Letras, 12, Alicante.</p>

  <h2>Nuestra recomendación</h2>
  <p>El hobbit, de J. R. R. Tolkien.</p>

  <p>Versión 2 — Servidor 2</p>
  <hr>
  <small>Desplegado por Etienne Martinez en el servidor $(hostname) el $(date '+%d/%m/%Y %H:%M')</small>
</body>
</html>
EOF