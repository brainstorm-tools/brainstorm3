function tests = dataPipeTest()
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
rootPath = fullfile(fileparts(mfilename('fullpath')), '..', '..');
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(rootPath));
end

function setup(testCase)
testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
end

function testAppend(testCase)
filename = 'testIterativeWrite.h5';
name = '/test_data';

maxDims = [10 13 15];
chunkDims = [10 13 1];
dataType = 'uint8';
Pipe = types.untyped.DataPipe(maxDims,...
    'chunkSize', chunkDims,...
    'dataType', dataType,...
    'compressionLevel', 5,...
    'axis', 3);

%% create test file
fid = H5F.create(filename);

initialData = createData(dataType, [10 13 10]);
Pipe.data = initialData;
Pipe.export(fid, name, {}); % bind

H5F.close(fid);

%% append data
totalLength = 3;
appendData = zeros([10 13 totalLength], dataType);
for i = 1:totalLength
    appendData(:,:,i) = createData(dataType, chunkDims);
    Pipe.append(appendData(:,:,i));
end

%% verify data
fid = H5F.open(filename);
did = H5D.open(fid, name);

readData = H5D.read(did);

testCase.verifyEqual(readData(:,:,1:10), initialData);
testCase.verifyEqual(readData(:,:,11:end), appendData);

H5D.close(did);
H5F.close(fid);
end

function data = createData(dataType, size)
data = randi(intmax(dataType), size, dataType);
end