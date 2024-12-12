#!/bin/sh
cd ..
NODE_MODULES="node_modules"
if [ -d "$NODE_MODULES" ]; then
    npm start
else
    npm install && npm start
fi