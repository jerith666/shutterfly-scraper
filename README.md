This is a simple script to scrape and email the "recent activity" (or "news & updates" if "recent activity" doesn't exist) section of a Shutterfly site.

It requires `curl`, Node.js (`node` and `npm`), `js-beautify` (via `npm install js-beautify`), and `mail`.

It takes three arguments: `site-id`, `site-password`, and `recipients`.  For example, to email the recent activity at https://whitehouse.shutterfly.com to Edward Snowden, do:

    ./sfly-scrape.sh whitehouse n0mor3leeks snowden@lavamail.com

This script is obviously heavily dependent on the implementation details of Shutterfly sites, and will break should they change in any appreciable way.
