const path = require('path');

const WORKDIR = '/var/lib/tasmocompiler';
const tasmotaRepo = path.resolve(WORKDIR, 'Tasmota');
const githubRepo = 'https://github.com/arendst/Tasmota.git';
const edgeBranch = 'development';
const userConfigOvewrite = path.resolve(
  tasmotaRepo,
  'tasmota/user_config_override.h'
);
const userPlatformioIni = path.resolve(tasmotaRepo, 'platformio.ini');
const tcSrcCoresIni = '/opt/tasmocompiler/server/compile/tc_cores.ini';
const tcDestCoresIni = path.resolve(tasmotaRepo, 'tc_cores.ini');
const tasmotaVersionFile = path.resolve(
  tasmotaRepo,
  'tasmota/tasmota_version.h'
);
const templatePlatformioIni = '/opt/tasmocompiler/server/compile/platformio.ini';
const listenPort = process.env.PORT || 8000;

module.exports = {
  tasmotaRepo,
  githubRepo,
  edgeBranch,
  userConfigOvewrite,
  userPlatformioIni,
  tcSrcCoresIni,
  tcDestCoresIni,
  tasmotaVersionFile,
  templatePlatformioIni,
  listenPort,
};
