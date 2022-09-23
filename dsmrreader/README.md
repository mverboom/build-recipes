# DSMR reader

Smartmeter data collection suite.

There are two build recipes:

* dsmrreader.recipe

This is the full suite.

* dsmr-datalogger.recipe

This is only the data logger. This recipe is also set to be build for raspberry,
so a PI with a serial link to the smartmeter can upload data to the main system.

## Post installtion status

After installing the package, the setup will default run with sqlite.
Also the admin account is:

* login: admin
* password: admin

It might be smart to change this.

Recommended from the project is Postgresql, but mysql (mariadb) should
also work.

To change away from the default configured database, first change the
configuration:

vi /etc/dsmrreader/env

For mysql:

DJANGO_DATABASE_ENGINE=django.db.backends.mysql
DJANGO_DATABASE_HOST=<database host>
DJANGO_DATABASE_PORT=3306
DJANGO_DATABASE_NAME=<database name>
DJANGO_DATABASE_USER=<database user>
DJANGO_DATABASE_PASSWORD=<user pasword>

For postgresql:

DJANGO_DATABASE_ENGINE=django.db.backends.postgresql
DJANGO_DATABASE_HOST=<database host>
DJANGO_DATABASE_PORT=5432
DJANGO_DATABASE_NAME=<database name>
DJANGO_DATABASE_USER=<datbase user>
DJANGO_DATABASE_PASSWORD=<user pasword>

After doing this, the database needs to be initialised. Run the following:

```
su - dsmr -c ". .venv/bin/activate; . .env; ./manage.py migrate;"
systemctl restart dsmr_backend.service dsmr_datalogger.service dsmr_webinterface.service
```

