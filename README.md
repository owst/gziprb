# gziprb [![Build Status](https://travis-ci.org/owst/gziprb.svg?branch=master)](https://travis-ci.org/owst/gziprb)

`gziprb` is a pure-Ruby implementation of the famous [GZIP][3]/[DEFLATE][7]
format. It is (definitely!) not optimised for performance, but was instead
created as a learning exercise to try and better understand the gzip format.

## Usage

To compress a file use `gziprb INPUT_FILE`, which will create `INPUT_FILE.gz`
and not alter `INPUT_FILE`.

To decompress a file use `gunziprb INPUT_FILE.gz`, which will create
`INPUT_FILE` and will not alter `INPUT_FILE.gz`.

## Tests

`gziprb` is tested with unit tests (using [RSpec][5]) and shell integration
tests (using [bats][6]). To run all tests, use `bundle exec rake test` (or just
`bundle exec rake` as `test` is the default task).

bats and its extension libraries should be installed via the included
[`npm`][4] `package.json` using `npm install`.

In addition to the `npm` dependency, the integration tests use gzip/gunzip,
which may not be availabe, so only the unit tests can be run by using `bundle
exec rake spec`. Similarly, just the integration tests can be run with `bundle
exec rake integration_test`.

## Acknowledgements

The official gzip repository contains [puff.c][1] a simple implementation of
inflation of gzip-compressed files, which, along with [Joshua Davies'
blogpost][2] were very useful when first trying to get to grips with the
formats. [Michael Dipperstein's blogpost][8] contained several useful hints
regarding LZ77.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/owst/gziprb.

[1]: https://github.com/madler/zlib/blob/master/contrib/puff/puff.c
[2]: http://commandlinefanatic.com/cgi-bin/showarticle.cgi?article=art001
[3]: https://tools.ietf.org/html/rfc1951
[4]: https://www.npmjs.com/
[5]: http://rspec.info/
[6]: https://github.com/sstephenson/bats
[7]: https://tools.ietf.org/html/rfc1952
[8]: http://michael.dipperstein.com/lzss/
