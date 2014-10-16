# Swaggerific

A webservice which creates web service stubs from Swagger 2.0 documentation.

[Swaggerific](http://www.urbandictionary.com/define.php?term=Swaggerific&defid=5908632) (a): Having Swagger that exceeds the limit of 9000. Not commonly found.

## About

Have a read of [Swaggerific's homepage](public/index.html#about), the about section gives lots of information about how to use it.

## Code

You can download the code [from github](https://github.com/blinkboxbooks/swaggerific). If you think our work can be improved, please submit a pull request!

## Installation & execution

Swaggerific can run in two modes. **Single service** mode will mock a single service using a specified swagger file; **Multi service** must sit behind a wildcard DNS entry and allows users to upload swagger files to stub.

By default the service runs in **Multi service** mode, but you can change this by setting the `SWAGGERIFIC_SINGLE_SERVICE` environment variable to the path of a swagger yaml file.

In **Multi service** mode swaggerific assumes you are running on a 3 component domain (eg. swaggerific.example.com). If you are pointing a different domain at swaggerific you can change this by setting the `SWAGGERIFIC_TLD_LEVEL` to a positive number, eg `2` for swaggerific.labs.blinkboxbooks.com

### Locally

```
git clone https://github.com/blinkboxbooks/swaggerific.git
cd swaggerific
gem install foreman
bundle install
foreman start -p 5000
```

### Getting going on Heroku

```
git clone https://github.com/blinkboxbooks/swaggerific.git
cd swaggerific
heroku create
heroku domains:add swaggerific.example.com
heroku domains:add '*.swaggerific.example.com'
heroku config:set SWAGGERIFIC_TLD_LEVEL=3
git push heroku master
# Now ensure swaggerific.example.com and *.swaggerific.example.com have CNAME DNS entries pointing to your heroku app.
```
