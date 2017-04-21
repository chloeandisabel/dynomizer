# Dynomizer

Dynomizer automatically modifies [Heroku](https://heroku.com/)
and [HireFire](https://hirefire.io/) Dyno scaling rules on schedule. It
reads scaling rules from a database and runs them based on their `crontab`-
or `at`-like scheduling specifications. These rules modify Heroku Dyno
formation quantities or HireFire manager numbers like minimimum and maximum
by specifying absolute numbers (12, +3, -5), percentages (+25%, -20%), or
multiples or divisors (*2, *0.5x, /2, /3).

Dynomizer is a [Phoenix](http://www.phoenixframework.org/) application. The
web interface is used to edit the records in the database.

# Usage

When Dynomizer starts, it reads all of the records from the `schedules`
database table and schedules them for execution. Every minute, the table is
checked for new or changed records.

The main page of the application list all of the schedules in memory, with
edit and delete links.

## Miscellaneous

All dates and times are UTC. `at` schedule strings should not specify any
time zone offset.

See https://github.com/c-rack/quantum-elixir for the `crontab`-like schedule
format.

## Configuration

A `Dynomizer.HerokuSchedule` record  has a number of fields which map to
the exposed Formation API values in the HireFire API.

- `application` - Heroku application name
- `dyno_type` - Heroku dyno type
- `rule` - See below
- `min` - Minimum dyno count, default is 0
- `max` - Maximum dyno count, default is 0xffffffff
- `schedule` - See below
- `description` - Optional

A `Dynomizer.HirefireSchedule` record has a number of fields which map to
the exposed Manager API values in the HireFire API. Not all HireFire manager
values are exposed via their API (for example, web server response times and
upscale and downscale sensitivity and timeout settings), and not all of the
exposed values are used by Dynomizer (for example, notification settings).

- `application` - Heroku application name
- `dyno_type` - Heroku dyno type
- `type` - Dyno type / metric source / metric type
- `enabled` - HireFire rule enabled flag
- `min_rule` - See below
- `min` - Minimum dyno count, default is 0
- `max_rule` - See below
- `max` - Maximum dyno count, default is 0xffffffff
- `ratio_rule`
- `ratio` - Add one dyno for every _X_ jobs
- `decrementable` - Allow the manager to scale down dynos to the current
  minimum while there are still jobs in the queue
- `schedule` - See below
- `description` - Optional

Additional fields are used internally to keep track of the state of a
schedule.

## Rules

Rules must be in one of the following formats:

- An integer, optionally preceded by a sign (e.g., 12, +3, -5).
- A percentage, optionally preceded by a sign (e.g., 80%, +10%, -5%).
  Percentages may be floats (e.g., +10.5%).
- A multiplication or division sign followed by a number (e.g., /2, *3.5).

Dynomizer first asks Heroku for the current number of dynos. It then applies
the rule to that number, rounding to the nearest integer. It next clamps the
value between min and max inclusive.

A reminder: starting with one number, adding X%, then subtracting X%, does
not wind up with the original number. For example 100 + 30% = 130, but 130 -
30% = 91.

## Schedules

Schedules are either `crontab` strings or timestamps. All times are
treated as UTC.

# Deploying

To deploy Dynomizer to Heroku, see
http://www.phoenixframework.org/docs/heroku.

## Environment

Dynomizer uses the following environment variables. The Heroku deployment
doc at http://www.phoenixframework.org/docs/heroku talks about the settings
for the first three.

- `SECRET_KEY_BASE` for app security
- `POOL_SIZE` for database connections
- `DATABASE_URL` is set when the database is created
- `HEROKU_API_KEY` for the Heroku API

Optional:

- `BASIC_AUTH_USERNAME`
- `BASIC_AUTH_PASSWORD`
- `BASIC_AUTH_REALM` defaults to "Application"

If username and password are specified, HTTP Basic authentication is
required to access the web app. If either is specified, both must be.

# The Code

This is a stock Phoenix app with only a few additions and tweaks. For the
rest of this section, assume all module names are prefixed with
`Dynomizer.`.

The `HirefireSchedule` and `HerokuSchedule` models are in `web/models`. The
controller, view, and templates for editing them are all in
`web/{controllers,views,templates}`.

The `lib/dynomizer` directory contains the modules that schedule and run the
dyno scaling: `Scheduler`, `Rule`, `Heroku`, and `HireFire`. The two other
modules in this directory (`Endpoint` and `Repo`) are standard Phoenix
modules.

The scheduler is a GenServer that is managed by the app, which means that it
will be auto-restarted if anything goes wrong. The scheduler runs its
`refresh` function once a minute. When the scheduler is initialized, the
Heroku API module to use must be passed in. For all but the test environment
that's `Heroku`. For testing it is passed a mock module that's defined in
`test/test_helper.exs`.

`config/test.exs` makes sure that tests use a mock Heroku API module.

# To Do

- Need an easy way to copy an existing schedule --- a "copy and edit" button
  would be nice on the schedule index and show pages.

# Phoenix

To start your Phoenix app:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `npm install`
  * Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
