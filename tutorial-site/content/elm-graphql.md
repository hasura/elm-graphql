---
title: "Generate Elm Types"
metaTitle: "Elm GraphQL Client Setup | GraphQL Elm Tutorial"
metaDescription: "You will learn how to install elm-graphql"
---

import GithubLink from "../src/GithubLink.js";

We looked into the problems of making a GraphQL query from an elm application without valid types. Elm GraphQL [cli](https://www.npmjs.com/package/@dillonkearns/elm-graphql#setup) is a tool which spits out elm types by introspecting the GraphQL url. We can use them while performing any GraphQL operation from the app.

### Elm GraphQL CLI Installation
Let's get started by installing elm-graphql:

```bash
$ npm install --save-dev @dillonkearns/elm-graphql
```

### Generate Elm Types
Let's generate Elm Types by adding a script to our package.json file as follows

Open `package.json` and add the following script:

<GithubLink link="https://github.com/hasura/graphql-engine/blob/master/community/learn/graphql-tutorials/tutorials/elm/app-final/package.json" text="package.json" />

```json
{
  "name": "elm-todo-hasura",
  "version": "0.0.1",
  "description": "Simple todo app using Hasura GraphQL Engine and dillonkearns/elm-graphql",
  "main": "src/index.js",
  "directories": {
    "test": "tests"
  },
  "scripts": {
    "build": "node scripts/build.js",
    "start": "node scripts/start.js",
    "make": "elm make",
    "repl": "elm repl",
    "reactor": "elm reactor",
+   "test": "echo \"Error: no test specified\" && exit 1",
+   "generate-elm-types": "elm-graphql https://learn.hasura.io/graphql --base Hasura"
  },
  "keywords": [
    "Elm",
    "GraphQL",
    "Hasura",
    "TodoMVC"
  ],
  "author": "Karthik V",
  "license": "ISC",
  "dependencies": {},
  "devDependencies": {
    "@babel/cli": "7.2.3",
    "@babel/core": "7.3.4",
    "@babel/plugin-transform-runtime": "7.3.4",
    "@babel/preset-env": "7.3.4",
    "@babel/runtime": "7.3.4",
    "assets-webpack-plugin": "^3.5.1",
    "autoprefixer": "^8.0.0",
    "babel-loader": "8.0.4",
    "babel-runtime": "^6.26.0",
    "@dillonkearns/elm-graphql": "^3.6.2",
    "case-sensitive-paths-webpack-plugin": "^2.1.2",
    "chalk": "^2.3.1",
    "clean-webpack-plugin": "^0.1.18",
    "connect-history-api-fallback": "^1.5.0",
    "cosmiconfig": "^5.0.6",
    "css-loader": "^0.28.9",
    "dotenv": "^5.0.0",
    "elm": "0.19.0-bugfix6",
    "elm-hot-webpack-loader": "^1.0.2",
    "elm-test": "^0.19.0-rev5",
    "elm-webpack-loader": "^5.0.0",
    "file-loader": "^1.1.6",
    "html-webpack-plugin": "^4.0.0-alpha.2",
    "http-proxy-middleware": "^0.17.4",
    "mini-css-extract-plugin": "^0.4.0",
    "minimist": "1.2.0",
    "postcss-flexbugs-fixes": "^3.3.0",
    "postcss-loader": "2.1.5",
    "promise": "8.0.1",
    "react-dev-utils": "6.1.1",
    "react-error-overlay": "^4.0.0",
    "string-replace-loader": "^2.1.1",
    "style-loader": "^0.21.0",
    "sw-precache-webpack-plugin": "^0.11.5",
    "uglifyjs-webpack-plugin": "^1.2.4",
    "url-loader": "^1.0.1",
    "webpack": "^4.30.0",
    "webpack-cli": "^3.3.1",
    "webpack-dev-server": "^3.1.1",
    "webpack-manifest-plugin": "^2.0.3",
    "whatwg-fetch": "2.0.4"
  },
  "now": {
    "alias": ""
  }
}

```

Before we generate our types, we will require an `Authorization` token to access the GraphQL server. Lets login using the below link and get the `Authorization Token`

[learn.hasura.io/graphql/graphiql?tutorial=react-native](https://learn.hasura.io/graphql/graphiql?tutorial=react-native)

#### TODO add screenshot of the token

Copy the `Authorization Token` header as in the screenshot and execute the following command to generate elm types

```bash
npm run generate-elm-types -- --header "Authorization: Bearer <token>"
```

You should see a folder called `Hasura` inside `src/` as in the screenshot below

#### TODO add screenshot of the terminal
