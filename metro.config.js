const { getDefaultConfig } = require("expo/metro-config");
const exclusionList = require("@expo/metro/metro-config/defaults/exclusionList").default;

const config = getDefaultConfig(__dirname);

config.resolver.blockList = exclusionList([
  /\/\.(agents|codex|git)(\/.*)?$/,
]);

module.exports = config;
