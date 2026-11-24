# Root site for universal links

iOS opens invite links (`https://johannesnorbertwolf.github.io/moonlight/?join=CODE`) directly in the Moonlight app only if `https://johannesnorbertwolf.github.io/.well-known/apple-app-site-association` exists. That path belongs to the GitHub Pages *user site*, which is a separate repository named `johannesnorbertwolf.github.io`.

To set it up, create that public repository with the files in this folder (`.nojekyll` makes GitHub Pages serve the `.well-known` folder; `index.html` forwards to the app), and turn on Pages for its main branch. Then check:

```bash
curl -s https://johannesnorbertwolf.github.io/.well-known/apple-app-site-association
```

Apple fetches the file through its CDN when the app is installed, so it can take a while; reinstalling the app makes iOS fetch it again. Without this, links still work: they open the web app, which offers "Open in the Moonlight iPhone app".
