# Dynomizer

Dynomizer automatically scales Heroku Dynos on schedule. It reads schedules
from a database using `crontab`- or `at`-like scheduling specifications.
Dyno counts are increased or decreased by specifying absolute numbers (12,
+3, -5), percentages (+25%, -20%), or multiples or divisors (*2, *0.5x, /2,
/3).

Dynomizer is a [Phoenix](http://www.phoenixframework.org/) application. The
web interface is used to edit the records in the database and to start and
stop the scheduler.

# Environment

Dynomizer uses the following environment variables. See
http://www.phoenixframework.org/docs/heroku for setting all but the first of
these.

- `HEROKU_API_KEY` for the Heroku API
- `SECRET_KEY_BASE` for app security
- `POOL_SIZE` for database connections
- `DATABASE_URL` is set when the database is created

# Usage

When Dynomizer starts, it reads all of the records from the `schedules`
database table and schedules them for execution. Every minute, the table is
checked for new or changed records.

The main page of the application is a dashboard with the following elements:
- Status (running, stopped)
- Start/stop buttons
- List of schedules in memory with edit and delete links

## Miscellaneous

All dates and times are UTC.

See https://github.com/c-rack/quantum-elixir for the `crontab`-like schedule
format.

## Configuration

A `Dynomizer.Schedule` record has the following fields:

- `application` - Heroku application name
- `dyno_type` - Heroku dyno type
- `rule` - See below
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
the rule to that number, rounding to the nearest integer.

A reminder: starting with one number, adding X%, then subtracting X%, does
not wind up with the original number. For example 100 + 30% = 130, but 130 -
30% = 91.

## Schedules

Schedules are either `crontab` strings or timestamps. All times are treated
as UTC.

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
