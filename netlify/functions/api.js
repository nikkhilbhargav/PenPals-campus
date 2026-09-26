'use strict';
const serverless = require('serverless-http');
const { app, ready } = require('../../server');

let readiness;
const expressHandler = serverless(app);
exports.handler = async (event, context) => {
  readiness ||= ready();
  await readiness;
  return expressHandler(event, context);
};
