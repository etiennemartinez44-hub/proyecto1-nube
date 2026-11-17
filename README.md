# Proyecto 1: Mi web en AWS

**Alumno:** Etienne Martinez  
**Entorno:** AWS Academy Learner Lab  
**Región:** Norte de Virginia (`us-east-1`)

## Objetivo

En este proyecto he desplegado la web de Librería Tinta en AWS. Primero he creado la red y el servidor desde la consola. Después he añadido una segunda versión de la web con DNS ponderado y he automatizado el despliegue de otro servidor con AWS CLI.

## Arquitectura

![Diagrama de arquitectura](img/arquitectura.svg)

Los servidores están en la misma VPC y subred. Los dos primeros comparten el grupo de seguridad `libreria-web-sg`. El servidor creado por el script utiliza otro grupo, `libreria-web-cli-sg`, y no forma parte del reparto DNS.

## Nivel básico

### Red

He creado cada recurso por separado, sin utilizar el asistente «VPC y más» ni crear una NAT Gateway.

| Recurso | Nombre | Configuración |
|---|---|---|
| VPC | `libreria-vpc` | `10.0.0.0/16`; resolución DNS y nombres de host DNS habilitados |
| Subred | `libreria-publica` | `10.0.1.0/24`, zona `us-east-1a`, IPv4 pública automática habilitada |
| Gateway de internet | `libreria-igw` | Asociada a la VPC |
| Tabla de rutas | `libreria-rt-publica` | Asociada a la subred; ruta `0.0.0.0/0` hacia la gateway |

La subred es pública porque su tabla tiene una ruta hacia la gateway de internet. Además, el servidor tiene una IP pública y las reglas necesarias para recibir las visitas a la web.

![VPC](img/01-vpc.png)
![Subred](img/02-subred.png)
![Gateway de internet](img/03-igw.png)
![Rutas](img/04-tabla-rutas.png)
![Asociación de la subred](img/05-asociacion-subred.png)

### Seguridad

| Tipo | Puerto | Origen |
|---|---|---|
| HTTP | 80 | `0.0.0.0/0` |
| SSH | 22 | Mi IP pública con máscara `/32` |

HTTP está abierto para que cualquiera pueda visitar la web. SSH solo se permite desde mi IP para limitar el acceso de administración. Si cambia mi IP, hay que actualizar la regla antes de conectarse.

![Grupo de seguridad](img/06-grupo-seguridad.png)

### Primer servidor

La instancia `libreria-web` utiliza Amazon Linux 2023, arquitectura x86, tipo `t3.micro`, el par de claves `vockey` y un disco gp3 de 8 GiB. Tiene las etiquetas `Proyecto = P1` y `Alumno = Etienne Martinez`.

El archivo [user-data1.sh](scripts/user-data1.sh) instala Nginx, lo inicia y escribe la página HTML con el horario, la dirección y una recomendación de libro. También muestra mi nombre, el nombre del servidor y la fecha del despliegue.

![Instancia](img/07-instancia.png)
![Primera web](img/08-web1.png)
![Etiquetas](img/09-etiquetas.png)

### Comprobación por SSH

Me he conectado desde PowerShell con la clave privada del laboratorio. Dentro del servidor he ejecutado:

```bash
whoami
hostname
systemctl is-active nginx
curl -I http://localhost
```

El usuario era `ec2-user`, Nginx estaba `active` y la respuesta HTTP era `200 OK`.

![Prueba SSH](img/10-ssh.png)

## Nivel medio: segunda web y DNS ponderado

He creado `libreria-web2` con la misma VPC, subred y grupo de seguridad. Utiliza [user-data2.sh](scripts/user-data2.sh), que muestra «Librería Tinta - Novedades», recomienda El hobbit y lleva la indicación «Versión 2 — Servidor 2».

![Segundo servidor](img/12-instancia2.png)
![Segunda web](img/13-web2.png)

He creado la zona alojada privada `libreria.lab`, asociada a `libreria-vpc`, y estos registros:

| Nombre | Tipo | IP privada | Política | Peso | ID | TTL |
|---|---|---|---|---|---|---|
| `web.libreria.lab` | A | `10.0.1.187` | Ponderada | 80 | `servidor1` | 10 s |
| `web.libreria.lab` | A | `10.0.1.224` | Ponderada | 20 | `servidor2` | 10 s |

El nombre solo se resuelve dentro de la VPC. Las visitas desde internet a las webs se comprueban usando la IP pública de cada instancia.

![Zona privada](img/14-zona-privada.png)
![Registros ponderados](img/15-registros-dns.png)

Desde SSH en el primer servidor he ejecutado:

```bash
nslookup web.libreria.lab
```

El nombre resolvió a `10.0.1.187`.

![Resolución DNS](img/16-prueba-dns.png)

Después hice 20 peticiones, dejando 11 segundos entre ellas para superar el TTL:

```bash
for i in {1..20}; do
  curl --connect-timeout 5 --max-time 10 -sS http://web.libreria.lab | grep 'Versión'
  sleep 11
done
```

Recibí 17 respuestas del servidor 1 y 3 del servidor 2. La prueba demuestra que ambos responden mediante el nombre DNS. Los pesos 80/20 no garantizan un reparto exacto en una muestra de 20 peticiones; también influye la caché DNS.

![Respuestas de ambas versiones](img/17-prueba-webs-dns.png)

## Presupuesto

Las estimaciones representan funcionamiento continuo 24/7, con Linux bajo demanda, disco gp3 de 8 GB por instancia y una IPv4 pública por servidor. No representan el consumo real del Learner Lab. No se han añadido tráfico saliente de pago, instantáneas ni monitorización detallada. Los importes no incluyen impuestos y pueden variar.

| Concepto | Básico | Medio |
|---|---:|---:|
| EC2 y discos | 8,23 USD/mes | 16,46 USD/mes |
| IPv4 públicas | 3,65 USD/mes | 7,30 USD/mes |
| Zona DNS privada | — | 0,50 USD/mes |
| **Total** | **11,88 USD/mes** | **24,26 USD/mes** |

- [Estimación del nivel básico](https://calculator.aws/#/estimate?id=5633d90614d61f9b031efd06e19d4518b27bdd12)
- [Estimación del nivel medio](https://calculator.aws/#/estimate?id=85afe40151e6006e7bb0ceb2485462e741bb3382)

Las consultas de la zona privada no tienen coste adicional, según los [precios de Route 53](https://aws.amazon.com/route53/pricing/).

Para reducir el gasto del laboratorio detengo las instancias cuando no las utilizo. Mientras están detenidas se mantiene el coste del almacenamiento. El servidor del avanzado es una instancia adicional de demostración y no está incluido en los presupuestos anteriores.

![Presupuesto básico](img/11-presupuesto-basico.png)
![Presupuesto medio](img/18-presupuesto-medio.png)

## Nivel avanzado: despliegue desde la terminal

El archivo [desplegar.sh](scripts/desplegar.sh) reutiliza la VPC y subred del básico. Consulta la AMI de Amazon Linux 2023, crea `libreria-web-cli-sg`, permite HTTP y SSH desde mi IP, y lanza `libreria-web-cli` con el contenido de `user-data1.sh`. Después espera a que esté en ejecución y muestra su URL pública.

Lo he ejecutado desde CloudShell en `us-east-1`, subiendo los dos archivos a la misma carpeta:

```bash
bash -n desplegar.sh
bash desplegar.sh
```

Antes de ejecutarlo en otro entorno hay que revisar `VPC_ID`, `SUBNET_ID`, `MI_IP`, `ALUMNO` y que exista el par de claves `vockey`. Los archivos deben tener finales de línea LF y guardarse en UTF-8 sin BOM.

La ejecución creó la instancia `i-08b579fc59462cad3` y mostró `http://3.87.240.46`. Comprobé la web desde el navegador. El estado running no significa que Nginx ya haya terminado de instalarse, por lo que puede hacer falta esperar uno o dos minutos más.

![Ejecución del script](img/19-despliegue-cli.png)
![Web creada por CLI](img/20-web-cli.png)

El script no se puede repetir directamente si ya existe `libreria-web-cli-sg`: fallará con `InvalidGroup.Duplicate`. Para repetir la demostración hay que retirar previamente solo los recursos del despliegue CLI (primero terminar su instancia y esperar, y después borrar su grupo de seguridad). Los recursos del básico y del medio se conservan.

## Incidencias y uso de IA

He utilizado ChatGPT/Codex como ayuda para entender el enunciado, configurar los recursos paso a paso, preparar los scripts y redactar la documentación a partir de las pruebas realizadas.

Algunos prompts que he utilizado son:

1. «Mira el ZIP y el enunciado y explícame de qué va el proyecto para ir haciéndolo los dos».
2. «Hazme una tabla de lo que llevamos y lo que falta también para el medio y avanzado».
3. «Cuando haya que hacer captura o lo que sea, dímelo para no saltárnoslo».

La primera propuesta de ejecución del script no tuvo en cuenta que Windows lo había guardado con finales de línea CRLF. Al ejecutarlo en CloudShell apareció `invalid option name ... pipefail`. Comprobé el problema al convertir los archivos a LF y volver a ejecutar: entonces el despliegue terminó y pude abrir la web.

```bash
sed -i 's/\r$//' desplegar.sh user-data1.sh
```

Después cambié a LF los tres archivos locales desde VS Code. También tuve que restringir los permisos del archivo PEM en Windows porque SSH lo rechazaba por tener permisos demasiado abiertos. Tras corregirlos, la conexión funcionó.

No se incluyen claves privadas ni credenciales de AWS en este repositorio.

## Vídeo

**Pendiente: grabar el vídeo de 3–5 minutos y sustituir esta línea por su enlace.**

En el vídeo mostraré la red, el grupo de seguridad, las webs, SSH, el presupuesto, el DNS ponderado y la ejecución del script. Se escuchará mi voz y apareceré al menos en la presentación.

## Conservación de los recursos

Al terminar las sesiones detengo las instancias sin eliminar los recursos que debe revisar la profesora. Al arrancarlas de nuevo, las IP públicas pueden cambiar; por eso las IP visibles en las capturas corresponden al momento de cada prueba. El DNS ponderado utiliza las IP privadas.
