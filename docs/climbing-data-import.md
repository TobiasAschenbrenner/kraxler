# Importing climbing data and photo topos

The climbing sample has 40 climbing areas, 24 child sectors and 399 routes.
Use the separate topo data package for the JSON files and 28 PNG images.
The three ordinary gallery photographs have been removed.

## Storage

Areas keep the existing `name`, `type`, optional `parentAreaId` and GeoJSON
`location` fields. Routes keep their existing area reference, location,
discipline, grade, styles and optional length, pitches and description.

A route may additionally have a `topos` array. Each entry contains an image ID,
an HTTPS `imageUrl`, an optional `cloudinaryPublicId`, its `routeNumber` on the
shared topo and the image's pixel dimensions. Multiple routes can refer to the
same Cloudinary image with different route numbers. Image bytes stay in
Cloudinary; MongoDB stores the links and associations.

The route API returns these optional entries. iOS decodes them, displays the
topo and route number on route details, and retains the metadata in downloaded
route records. Existing routes and downloaded records without topos still work.
Image bytes are loaded over the network; saving route metadata does not itself
download the image for guaranteed offline viewing.

Original source links and credits stay in the package's separate reference file.
They are not imported into the application collections.

## Validate and import

Run from `backend/`, with the target database configured in `.env`:

```sh
npm run import:climbing -- --data /absolute/path/sample-data.json --media /absolute/path/media.json
```

This validates every record against the actual Mongoose models, checks grade
ranks and parent references, and does not connect to the database.

To apply the import, provide a new backup filename and an output for ID mappings:

```sh
npm run import:climbing -- \
  --data /absolute/path/sample-data.json \
  --media /absolute/path/media.json \
  --apply \
  --backup /private/path/climbing-backup.json \
  --id-map /private/path/climbing-id-map.json
```

The importer saves existing area/route records before its first update and
refuses to overwrite an existing backup file. Matching records are upserted;
unrelated records are retained. A unique nearby crag can be reused under its
existing region parent, including the seeded Röthelfels and Cuvier records.
Known existing styles are preserved when the sample has no style information.
Running the same import again does not create duplicates. Sample-to-database
ID mappings account for reused IDs. The import is not a transaction; if a
database error interrupts it, keep the backup and rerun after resolving the error.

`media.json` stores one entry per topo with `url`, `cloudinaryPublicId`, image
dimensions and `routeNumberMappings`. A null URL means the image has not been
uploaded and is skipped. Populated URLs are validated before database writes.
Topo entries already embedded in the route records can also be imported without
`--media`.

## Data limits

Route coordinates are crag/sector reference points, not surveyed route starts.
Knappenwand uses a source approach point. Six Austrian area samples were collected
from indexed pages because live access failed; the package retains their review
notes. Unknown lengths and pitch counts remain omitted. A missing topo association
means none was collected for this sample, not that no topo exists.

## Checks

Backend integration tests cover repeated imports, preserving seed IDs and region
parents, Cloudinary associations in route responses and rejecting invalid URLs.
iOS tests cover old route responses, topo decoding and SwiftData round trips.
