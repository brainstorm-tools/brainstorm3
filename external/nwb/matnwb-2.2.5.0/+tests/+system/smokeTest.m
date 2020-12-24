function tests = smokeTest()
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
rootPath = fullfile(fileparts(mfilename('fullpath')), '..', '..');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(rootPath));
% corePath = fullfile(rootPath, 'schema', 'core', 'nwb.namespace.yaml');
% testCase.TestData.registry = generateCore(corePath);
end

function teardownOnce(testCase)
% classes = fieldnames(testCase.TestData.registry);
% files = strcat(fullfile('+types', classes), '.m');
% delete(files{:});
end

function setup(testCase)
testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
end

%TODO rewrite namespace instantiation check
function testSmokeInstantiateCore(testCase)
% classes = fieldnames(testCase.TestData.registry);
% for i = 1:numel(classes)
%     c = classes{i};
%     try
%         types.(c);
%     catch e
%         testCase.verifyFail(['Could not instantiate types.' c ' : ' e.message]);
%     end
% end
end

function testSmokeReadWrite(testCase)
epochs = types.core.TimeIntervals(...
    'colnames', {'id' 'start_time' 'stop_time'} .',...
    'id', types.hdmf_common.ElementIdentifiers('data', 1),...
    'description', 'test TimeIntervals',...
    'start_time', types.hdmf_common.VectorData('data', 0, 'description', 'start time'),...
    'stop_time', types.hdmf_common.VectorData('data', 1, 'description', 'stop time'));
file = NwbFile('identifier', 'st', 'session_description', 'smokeTest', ...
    'session_start_time', datetime, 'intervals_epochs', epochs,...
    'timestamps_reference_time', datetime);

nwbExport(file, 'epoch.nwb');
readFile = nwbRead('epoch.nwb');
% testCase.verifyEqual(testCase, readFile, file, ...
%     'Could not write and then read a simple file');
tests.util.verifyContainerEqual(testCase, readFile, file);
end