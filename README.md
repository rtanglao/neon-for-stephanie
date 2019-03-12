# 11March add synthetic_gallery_id for neon1 and neon2 and download originals for neon2

```bash
./add-synthetic-galleryid-get-gallery-photo-metadata.rb 72157675774023387 2>neon2-add-galleryid-stderr.out &
./add-synthetic-galleryid-get-gallery-photo-metadata.rb 72157675752554377 2>neon1-add-galleryid-stderr.out &
git mv ORIGINALS NEON1_ORIGINALS
mkdir NEON2_ORIGINALS ; cd !$
../backup-originals-by-galleryid.rb
```

# 10March2019 setup the database and download metadata and download originals

```bash
. ./setupFlickrNeonDB
./get-gallery-photo-metadata.rb 72157675752554377 2>stderr.out
mkdir ORIGINALS ; cd !$
../backup-originals.rb
```
