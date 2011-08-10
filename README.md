Kohlrabi is a [Tornado](https://github.com/facebook/tornado) based webapp for viewing tabular report data.

Out of the Box Example
======================

You can try running kohlrabi immediately like this:

    example/launch_server_example.sh
    python example/push_data_example.py

This will start a Kohlrabi server instance at http://localhost:8888/kohlrabi/. 
Then push_data_example.py will push some fake data to the server in JSON form to
http://localhost:8888/kohlrabi/upload/. You can then browse two different data
reports for two different days each: 'Daily Signups' and 'MySQL Query Report' for
the days of 2011-02-14 and 2011-02-13.

Customizing Kohlrabi
====================

Out of the box, Kohlrabi includes two sample module definitions in `kohlrabi/modules/example.py`.
The two modules are `Daily Signups` and 'MySQL Query Report`. These are meant to be 
inspirational templates for the types of reports you might want to put into
Kohlrabi by showing you how to create/add new modules. However, they're probably not immediately
useful to most people; you will need to customize what data they store in Kohlrabi
to satisfy your needs.

The way customization works in Kohlrabi is to create a new Python file in the
same format as the one in `kohlrabi/modules/example.py` (look at the source
code). In the configuration file, you'll specify this as your `module`; this
module should be something available in `sys.path` that can be imported using
Python's `__import__` directive. (The example script works because the current
directory is automatically added to sys.path. You will certainly want to set it
manually in a production environment). Any SQLAlchemy tables in this module with the
metaclass `ReportMeta` will be detected by Kohlrabi as a potential data source,
which you can upload data for.

Reports are uploaded to Kohlrabi by making an HTTP POST request to the Kohlrabi
server, indicating the date, the data for the report, and the data source.

The next section will cover this in more detail.

Adding New Reports
==================

Setting up a Module
-------------------

It's easiest to explain this with an example. Suppose the report module
specified by the config `module` variable has the following code in it:
(This code is available in `kohlrabi/modules/example.py`)

    from sqlalchemy import *
    from kohlrabi.db import *
    
    class DailySignups(Base):
        __tablename__ = 'daily_signups_report'
        __metaclass__ = ReportMeta

        id = Column(Integer, primary_key=True)
        date = Column(Date, nullable=False)
        referrer = Column(String, nullable=False)
        clickthroughs = Column(Integer, nullable=False, default=0)
        signups = Column(Integer, nullable=False, default=0)
    
        display_name = 'Daily Signups'
        html_table = [
            ReportColumn('Referrer', 'referrer'),
            ReportColumn('Click-Throughs', 'clickthroughs'),
            ReportColumn('Signups', 'signups'),
            ]
    
        @classmethod
        def report_data(cls, date):
            return session.query(cls).filter(cls.date == date).order_by(cls.signups)

This is a data source that will track users who sign up on your site, based on
the HTTP `Referrer` header. The table has three columns: `referrer` will track
the domain that referred the initial visit to your site, `clickthroughs` will
track who many people came to the site from that referrer, and `signups` will
track how many of those people actually signed up.

Setting up the DataBase
-----------------------

The next step is to create the table in your Kohlrabi SQLite database. If you
don't do this, Kohlrabi will automatically create the table, but the table won't
have any indexes. In most cases you should probably at least add an index on the
`date` column, and probably an index on the full set of columns you plan on
querying from the `report_data` method:

    CREATE TABLE daily_signups_report (
        id INTEGER NOT NULL,
        date DATE NOT NULL,
        referrer VARCHAR NOT NULL,
        clickthroughs INTEGER NOT NULL,
        signups INTEGER NOT NULL,
        PRIMARY KEY (id)
    );
    CREATE INDEX daily_signups_date_idx ON daily_signups_report (date, signups);

OK, that's all the setup you need to do on the Kohlrabi side of things: create a
Python SQLAlchemy class, and create a table in your SQLite database. The second
step is to write a report that generates data to store in Kohlrabi. 

Sending data to Kohlrabi
-------------------------

You can do this however you want, in any language you want. This report should finish by
making a normal HTTP POST request to your Kohlrabi instance, with URL `/upload`,
and the following POST parameters:

* `date` -- the date for this data, in the format YYYY-MM-DD
* `module` -- the name of the Python class you defined earlier (in this example, `DailySignups`)
* `data` -- A JSON list of dictionaries mapping column names (excluding `id` and `date`) to their respective values

For instance, if we were running Kohlrabi on `http://localhost:8888`, then the
following Python code would generate a sample report for 2001-01-1:
(This code is available in kohlrabi/example/pusher_example.py)

    import json
    import urllib
    
    urllib.urlopen('http://localhost:8888/kohlrabi/upload',
         urllib.urlencode({'date': '2011-02-13',
                           'data': json.dumps([{'referrer': 'www.yahoo.com',
                                                'clickthroughs': 32984,
                                                'signups': 123},
                                               {'referrer': 'www.google.com',
                                                'clickthroughs': 23452,
                                                'signups': 432},
                                               {'referrer': 'www.excite.com',
                                                'clickthroughs': 82,
                                                'signups': 0},
                                               {'referrer': 'www.ask.com',
                                                'clickthroughs': 31,
                                                'signups': 0},
                                               {'referrer': 'www.cuil.com',
                                                'clickthroughs': 4,
                                                'signups': 0},
                                               {'referrer': 'www.bing.com',
                                                'clickthroughs': 21032,
                                                      'signups': 98}]),
                            'module': 'DailySignups'}))

Just to reiterate: because the interface to Kohlrabi is a normal HTTP request
using JSON, you can use any language to send data to Kohlrabi. You can use Java,
Ruby, a bash script, etc. Whatever works for you.

Configuration
=============

This section describes the parameters that can be placed in the config file. The
config file should be in YAML format. You can specify the path to the
configuration file by invoking `kohlrabi/main.py` with the `-c` option, e.g.
`python kohlrabi/main.py -c /etc/kohlrabi.yaml`.

* `database` -- this is a string with the SQLAlchemy-style path to the
  database. An example would be `sqlite:///foo.sqlite` for a `foo.sqlite` file
  in the current directory, or `sqlite:////tmp/foo.sqlite` for
  `/tmp/foo.sqlite`. You can also use MySQL, PostgreSQL, etc. For more details,
  refer to the upstream
  [SQLAlchemy Documentation](http://www.sqlalchemy.org/docs/core/engines.html#sqlalchemy.create_engine)
  on creating engines.
* `debug` -- forces debug mode. You can also invoke `main.py` with the `--debug`
  option to get the same effect (debug mode is enabled if either switch is on).
* `module` -- this is the name of the Python database module you're using. For
  instance, a valid value might be `kohlrabi.modules.example`. See below for
  more details on setting this value.
* `path_prefix` -- this changes the prefix used for all URLs internally within
  kohlrabi. For instance, you might run kohlrabi via Apache's `mod_proxy`
  ProxyPass, and all URLs should be prefixed with `/kohlrabi/`. The use of
  initial/trailing slashes here is not signficant, they'll be added if you omit
  them.

Running custom database modules is achieved by specifying a `module` in your
config file, or invoking `main.py` with the `-m` options. Internally, this is
implemented by Kohlrabi by using Python's `__import__` bulitin to load the
module. This means that if the location of the module is in a place that's not
in your default Python path, you should export that location via the
`PYTHONPATH` environment setting when invoking Kohlrabi.

For instance, suppose Kohlrabi is installed somewhere like
`/usr/lib/python2.7/site-packages` (or in any other site package directory). For
you custom module report, you created a file named
`/tmp/kohlrabi_reports/my_report.py`. When invoking Kohlrabi, you should run it
like so:

    PYTHONPATH="/tmp:$PYTHONPATH" python kohlrabi/main.py -m my_report

This will ensure that the `__import__` statement is able to find the module you
specified.
