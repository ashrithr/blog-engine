Blog Engine
===========

Blog engine using **Sinatra** and **MongoDB**, this is an exact replica of MongoDB developers training which is available in python using bottle.

MongoDB maintains 2 tables:

1. **users**, which contains user registration information provided during signup
2. **sessions**, which stores user sessions(cookies) per user login

Installation:
------------

```
bundle install
```

Usage
-----

```
bin/mongod
rackup
```