function tests = dataStubTest()
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
rootPath = fullfile(fileparts(mfilename('fullpath')), '..', '..');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(rootPath));
end

function setup(testCase)
testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
end

function testRegionRead(testCase)
date = datetime(2018, 3, 1, 12, 0, 0);
session_start_time = datetime(date,'Format','yyyy-MM-dd''T''HH:mm:SSZZ',...
    'TimeZone','local');
nwb = NwbFile( 'source', 'acquired on rig2', ...
    'session_description', 'a test NWB File', ...
    'identifier', 'mouse004_day4', ...
    'session_start_time', session_start_time);

data = reshape(1:5000, 1000, 5);

timeseries = types.core.TimeSeries(...
    'starting_time', 0.0, ... % seconds
    'starting_time_rate', 200., ... % Hz
    'data', data,...
    'data_unit','na');

nwb.acquisition.set('data', timeseries);
%%

nwbExport(nwb, 'test_stub_read.nwb');
nwb2 = nwbRead('test_stub_read.nwb');

stub = nwb2.acquisition.get('data').data;

%%
% test offset
testCase.verifyEqual(stub.load([2 2], [4 4]), data(2:4, 2:4));

% test Inf
testCase.verifyEqual(stub.load([2 2], [Inf Inf]), data(2:end, 2:end));

% test limit
testCase.verifyEqual(stub.load([1 1], [500 3]), data(1:500, 1:3));

% test stride
testCase.verifyEqual(stub.load([1 1], [2,2], [1000 4]), data(1:2:1000, 1:2:4));
end