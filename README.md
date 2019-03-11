# 10March2019 setup the database and download metadata and download originals

```bash
. ./setupFlickrNeonDB
./get-gallery-photo-metadata.rb 72157675752554377 2>stderr.out
mkdir ORIGINALS ; cd !$
../backup-originals.rb
```
