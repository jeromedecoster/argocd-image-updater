const express = require('express')


for (var name of ['APP_PORT']) {
    if (process.env[name] == null || process.env[name].length == 0) { 
        throw new Error(`${name} environment variable is required`)
    }
    console.log(`process.env.${name}: ${process.env.APP_PORT}`)
}

const APP_PORT = process.env.APP_PORT

const app = express()

app.get('/', (req, res) => {
    const json = require('./package.json')
    return res.json({[json.name]: json.version})
})

app.listen(APP_PORT, () => { 
    console.log(`Listening on port ${APP_PORT}`) 
})