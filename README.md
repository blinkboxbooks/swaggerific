# Swaggerific

A webservice which creates web service stubs from Swagger 2.0 documentation.

[Swaggerific's homepage](http://swaggerific.io#about) gives details of how to use swaggerific.

## Installation & execution

Use one of the methods below to get swaggerific listening somewhere, then ensure you have a DNS `A` record pointing there. If you're running in **Multi service** mode (default) then you'll also want a wildcard `CNAME` record pointing to your root domain too.

### Docker

If you have docker set up this is the fastest way to get going.

```
# From the docker hub:
docker run -P blinkboxbooks/swaggerific

# Or build it yourself:
git clone https://github.com/blinkboxbooks/swaggerific.git
cd swaggerific
docker build -t swaggerific .
docker run -P swaggerific
```

* You can include the flag `-e SWAGGERIFIC_TLD_LEVEL=2` to specify a level for the top level host.
* You can swap out `-P` for `-p 5000:8080` to serve up swaggerific on port `8080`.

### Locally

```
git clone https://github.com/blinkboxbooks/swaggerific.git
cd swaggerific
gem install foreman
bundle install
foreman start -p 5000
```

### Heroku

```
git clone https://github.com/blinkboxbooks/swaggerific.git
cd swaggerific
heroku create
heroku domains:add swaggerific.example.com
heroku domains:add '*.swaggerific.example.com'
heroku config:set SWAGGERIFIC_TLD_LEVEL=3
git push heroku master
```

## Configuration

Swaggerific can run in two modes. **Single service** mode will mock a single service using a specified swagger file; **Multi service** must sit behind a wildcard DNS entry and allows users to upload swagger files to stub.

By default the service runs in **Multi service** mode, but you can change this by setting the `SWAGGERIFIC_SINGLE_SERVICE` environment variable to the path of a swagger yaml file.

In **Multi service** mode swaggerific assumes you are running on a 3 component domain (eg. swaggerific.example.com). If you are pointing a different domain at swaggerific you can change this by setting the `SWAGGERIFIC_TLD_LEVEL` to a positive number, eg `4` for swaggerific.labs.blinkboxbooks.com

Now ensure swaggerific.example.com and *.swaggerific.example.com have CNAME DNS entries pointing to your heroku app.

## TODO

So far this is really only the product of a night's furious "oh damn, this would be so useful". I track feature's I'd like to add with [github issues](https://github.com/blinkboxbooks/swaggerific/issues). Test coverage and general code stink [need some work](https://codeclimate.com/github/blinkboxbooks/swaggerific) too. If you feel like helping PRs are greatfully received!

> [Swaggerific](http://www.urbandictionary.com/define.php?term=Swaggerific&defid=5908632) (a): Having Swagger that exceeds the limit of 9000. Not commonly found.