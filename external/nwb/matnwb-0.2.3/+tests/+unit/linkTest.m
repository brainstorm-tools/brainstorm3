function tests = linkTest()
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
rootPath = fullfile(fileparts(mfilename('fullpath')), '..', '..');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(rootPath));
end

function setup(testCase)
testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
end

function testExternLinkConstructor(testCase)
l = types.untyped.ExternalLink('myfile.nwb', '/mypath');
testCase.verifyEqual(l.path, '/mypath');
testCase.verifyEqual(l.filename, 'myfile.nwb');
end

function testSoftLinkConstructor(testCase)
l = types.untyped.SoftLink('/mypath');
testCase.verifyEqual(l.path, '/mypath');
end

function testLinkExportSoft(testCase)
fid = H5F.create('test.nwb');
close = onCleanup(@()H5F.close(fid));
l = types.untyped.SoftLink('/mypath');
l.export(fid, 'l1');
info = h5info('test.nwb');
testCase.verifyEqual(info.Links.Name, 'l1');
testCase.verifyEqual(info.Links.Type, 'soft link');
testCase.verifyEqual(info.Links.Value, {'/mypath'});
end

function testLinkExportExternal(testCase)
fid = H5F.create('test.nwb');
close = onCleanup(@()H5F.close(fid));
l = types.untyped.ExternalLink('extern.nwb', '/mypath');
l.export(fid, 'l1');
info = h5info('test.nwb');
testCase.verifyEqual(info.Links.Name, 'l1');
testCase.verifyEqual(info.Links.Type, 'external link');
testCase.verifyEqual(info.Links.Value, {'extern.nwb';'/mypath'});
end

function testPathResolution(testCase)
nwb = NwbFile;
dev = types.core.Device;
nwb.general_devices.set('testDevice', dev);
nwb.general_extracellular_ephys.set('testEphys',...
    types.core.ElectrodeGroup('device',...
    types.untyped.SoftLink('/general/devices/testDevice')));
testCase.verifyEqual(dev,...
    nwb.general_extracellular_ephys.get('testEphys').device.deref(nwb));
end
