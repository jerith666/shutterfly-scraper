This is a simple script to scrape and email the "recent activity" section of a Shutterfly site.

If the site you want to scrape has a "News & Updates" section rather than a "Recent Activity" section, try the `journal` branch instead of `master`.

It requires `curl`, Node.js (`node` and `npm`), `js-beautify` (via `npm install js-beautify`), and `mail`.

It takes three arguments: `site-id`, `site-password`, and `recipients`.  For example, to email the recent activity at https://whitehouse.shutterfly.com to Edward Snowden, do:

    ./sfly-scrape.sh whitehouse n0mor3leeks snowden@lavamail.com

This script is obviously heavily dependent on the implementation details of Shutterfly sites, and will break should they change in any appreciable way.
