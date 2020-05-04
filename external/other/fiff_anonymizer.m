function fiff_anonymizer(inFile, varargin)
% FIFF_ANONYMIZER Anonymizes fiff files.
%  FIFF_ANONYMIZER('filename.fif') anonymizes filename.fif
%  Functional Image File Format (FIFF) specifies how information inside a
%  fif file is built into a linked list of tags. Different information
%  fields typically are allocated in their own tag. Fiff_anonymizer
%  locates each tag where relevant information might be stored and
%  substitutes the data in the tag with either, values specified by the
%  user or default values. If the information tag is missing, no
%  additional information will be added to the output file. If a tag is
%  found in the input file, then it will always be found in the output
%  file, however with anonymized information. The input file is left
%  unaltered.
%
%  Dependencies:  No dependencies. This application is self-contained and
%          does not depend on any external library or toolset.
%
%  Example I.   fiff_anonymizer('filename.fif');
%
%  Example II.  fiff_anonymizer('filename.fif', ...
%                 'output_file', 'out_filename.fif', ...
%                 'set_measurement_date_offset', 30, ...
%                 'set_subject_birthday_offset', 10, ...
%                 'brute', true, ...
%                 'verbose', true, ...
%                 'delete_input_file_after', true, ...
%                 'delete_confirmation', true)
%
%  Options:
%
%  filename    example.fif
%              Required input with the name of the file to be
%              anonymized.
%
%  verbose     {true, false}       Default: false
%              Print detailed information during each step in the
%              anonymization process.
%
%  output_file  example_anonymized.fif
%               Name of the output file name. If not specified the
%               output file name will have the same name as the input
%               file, followed by the string "_anonymized" and will
%               have the same extension.
%
%  set_measurement_date_offset  Number of days
%               The input file contains several records of the moment
%               when the raw file was recorded. If this option is used,
%               the specified number of days will be subtracted to the
%               date stored in the file.
%
%  set_subject_birthday_offset  Number of days
%               If the input file contains the subject's date of birth,
%               the specified number of days will be subtracted to the
%               date of birth stored in the output file.
%
%  delete_input_file_after {true, false}   Default: false
%               To help anonymize a collection of fiff files, this
%               option will make the application to delete the input
%               file.
%
%  delete_confirmation   {true, false}   Default: true
%               If this option is set to true a confirmation message
%               will be printed to the user for confirmation before
%               deleting the input file.
%  brute   {true, false}      	Default: false
%               Additional Subject and Project information fields will
%               be anonymized.
%  quiet   {true, false}   Default: false
%               Quiet display option mode. Fiff_anonymizer runs but no
%               output is shown to the user, except for the prompt
%               shown whenever delete_input_file_after option is set
%               accordingly. This option overrides the verbose mode.
%
%
%  FIELDS ANONYMIZED BY DEFAULT:
%  File ID        Containing MAC address of the acquisition pc and the
%                 measurement date. If the 'set_measurement_date_offset'
%                 option is used, the date stored in the output
%                 file will be the same as in the input file minus
%                 the specified number of days. If the option is
%                 not used, a default date will be stored in the
%                 output file.
%  Measurement   Date   If the 'set_measurement_date_offset'
%                       option is used, the date stored in the output
%                       file will be the same as in the input file minus
%                       the specified number of days. If not, a
%                       specific default date (January 1st, 20000) will be stored 
%                       in the output file.
% 
%  Measurement   Comment  A description of the Acquisition system. A
%                         reference to the site where the acquisition
%                         machine is installed.
%  Experimenter
%  Subject ID
%  Subject First Name
%  Subject Middle Name
%  Subject Last Name
%  Subject Birthday   If the 'set_subject_birthday_offset' options is
%                     used, Subject Birthday in the output file will be
%                     equal to the input file minus the specified
%                     number of days. If not, a default date (January 1st, 2000) 
%                     will be stored in the output file.
%  Subject Comment
%  Subject Hospital ID
%  Project Persons
%
%  Fields anonymized only when 'brute' option is set to TRUE:
%
%  Subjcet's Sex
%  Subject's Handedness
%  Subject's Weight
%  Subject's Height
%  Project's ID
%  Project Name
%  Project Aim
%  Project Comment
%
%
%  Author: Juan Garcia-Prieto, juangpc@gmail.com
%  License: MIT
%
%  Version 0.9 - May 2020
%
VERSION = 0.9;
DATE = 'May 2020';
MAX_VALID_FIFF_VERSION = 1.3;

opts = configure_options(inFile, varargin{:});
outTagDir = [];
blockTypeList = [];
jumpAfterRead = true;

if opts.verbose
  disp('======================================================================');
  disp(' ');
  disp('FIFF ANONYMIZER');
  disp('Fiff_anonymizer removes personal identifiable information and personal');
  disp('health information from an input fiff file.');
  disp(['Version ' num2str(VERSION) ' - Date: ' DATE ]);
  disp(' ');
end

[inFid, ~] = fopen(opts.inputFile, 'r', 'ieee-be');
if(opts.verbose && inFid>0)
  display(['Input file opened: ' opts.inputFile]);
end
[outFid, ~] = fopen(opts.outputFile, 'w+', 'ieee-be');
if(opts.verbose && outFid>0)
  display(['Output file created: ' opts.outputFile]);
end

[inTag, endOfFile] = read_tag(inFid, jumpAfterRead); %#ok<ASGLU>
blockTypeList=update_block_type_list(blockTypeList, inTag);

% read first tag->fileID?->outFile
if(wrongFifVersion(inTag, MAX_VALID_FIFF_VERSION))
  fclose(inFid);
  fclose(outFid);
  delete(opts.outputFile);
  error('This appears to be an invalid file.');
end

% anonymize and write first tag to output tag
[outTag, ~] = censor_tag(inTag, blockTypeList, opts);
outTagDir = add_entry_to_tagDir(outTagDir, outTag, ftell(outFid));
outTag.next = 0;
write_tag(outFid, outTag);

% check pointer to tag directory
[inTag, endOfFile] = read_tag(inFid, jumpAfterRead); %#ok<ASGLU>
blockTypeList = update_block_type_list(blockTypeList, inTag);
if(inTag.kind ~= 101)
  error('Sorry! This is not a valid FIF file.');
end
inDirPos = dataArray2int(inTag.data);
if (inDirPos > 0)
  inFileHasTagDir = true;
else
  inFileHasTagDir = false;
end
[outTag, ~] = censor_tag(inTag, blockTypeList, opts);
outTagDir = add_entry_to_tagDir(outTagDir, outTag, ftell(outFid));
write_tag(outFid, outTag);
  
% for all the tags in the file
while (inTag.next ~= -1)
  [inTag, endOfFile] = read_tag(inFid, jumpAfterRead);
  if(endOfFile)
    break;
  end
  blockTypeList = update_block_type_list(blockTypeList, inTag);
  [outTag, ~] = censor_tag(inTag, blockTypeList, opts);
  if (outTag.next > 0)
    outTag.next = 0;
  end
  outTagDir = add_entry_to_tagDir(outTagDir, outTag, ftell(outFid));
  write_tag(outFid, outTag);
end
fclose(inFid);

if opts.verbose
  disp('Building Tag Directory for the anonymized file.');
end

if (inFileHasTagDir)
  outTagDir = add_final_entry_to_tagDir(outTagDir);
  outTagDirAddr = ftell(outFid);
  if opts.verbose
    disp(['Saving Tag Directory into ' opts.outputFile]);
  end
  write_directory(outFid, outTagDir, outTagDirAddr);

  ptrDIR_KIND = 101;
  ptrFREELIST_KIND = 106;
  if opts.verbose
    disp(['Updating file pointers in ' opts.outputFile]);
  end
  update_pointer(outFid, outTagDir, ptrDIR_KIND, outTagDirAddr);
  update_pointer(outFid, outTagDir, ptrFREELIST_KIND, -1);
end

fclose(outFid);

if ~opts.quiet
  disp(['Fiff_anonymizer finished correctly: ' opts.inputFile ' -> ' opts.outputFile]);
end

%file deletion
if opts.deleteFileAfter
  deleteThisFile = false;
  if opts.deleteConfirmation
    disp(' ');
    disp(['You have requested to delete the input file: ' opts.inputFile]);
    disp('You can avoid this confirmation by using the ''delete_confirmation'' option.');
    prompt = 'Are you sure you want to delete this file? [Y/n] ';
    userInput = input(prompt, 's');
    if(strcmp(userInput, 'Y') || strcmp(userInput, 'YES'))
      deleteThisFile = true;
    end
  else
    deleteThisFile = true;
  end
  if deleteThisFile
    if opts.verbose
      disp(['Deleting input file: ' opts.inputFile]);
    end
    delete(opts.inputFile);
  else
    if opts.verbose
      disp(['File ' opts.outputFile ' not deleted.']);
    end
  end
end

if opts.verbose
  disp(' ');
  disp('======================================================================');
  disp(' ');
end

end

function [tag, endOfFile] = read_tag(fid, jump)

if(nargin == 1)
  jump = false;
end

tag.kind = fread(fid, 1, 'int32');
tag.type = fread(fid, 1, 'int32');
tag.size = fread(fid, 1, 'int32');
tag.next = fread(fid, 1, 'int32');

endOfFile = feof(fid);

if(endOfFile)
  return;
end

if(tag.size > 0)
  tag.data = fread(fid, tag.size, 'uint8');
else
  tag.data = [];
end

if(jump && (tag.next > 0) )
  fseek(fid, tag.next, 'bof');
end


end

function write_tag(fid, tag)

fwrite(fid, int32(tag.kind), 'int32');
fwrite(fid, int32(tag.type), 'int32');
fwrite(fid, int32(tag.size), 'int32');
fwrite(fid, int32(tag.next), 'int32');
if(tag.size>0)
  fwrite(fid, tag.data, 'uint8');
end

end

function fileInfo = parse_fileID_tag(data)
fileInfo.version = (data(1)*16^2 + data(2)) + (data(3)*16^2 + data(4))/10;
fileInfo.time = dataArray2int(data(13:16)) + dataArray2int(data(17:20))/1e6;
fileInfo.mac = data(5:12);
%parsing mac address to text
%somewhat erratic. different elekta sites tend to code mac info in
%different places. sometimes since the initial byte sometimes at the end.
%don't know on what depends.
macStr = [];
if(data(12) == 0)
  for i = 5:10
    macStr = cat(2, macStr, [dec2hex(data(i), 2) ':']);
  end
else
  for i = 7:12
    macStr = cat(2, macStr, [dec2hex(data(i), 2) ':']);
  end
end
fileInfo.macStr = macStr(1:end-1);
end

function [outTag, sizeDiff] = censor_tag(inTag, blockTypeList, opts)

switch(inTag.kind)
  case {100, 103, 109, 110, 116, 120} %fileID
    inFileID = parse_fileID_tag(inTag.data);
    versionNum = inTag.data(1:4);
    newMacAddr = opts.defaultMAC;
    if opts.usingMeasDateOffset
      newDatePosix = floor(inFileID.time-24*60*60*opts.measDateOffset);
    else
      newDatePosix = opts.measDateDefault;
    end
    newDateData = [int2dataArray(newDatePosix);0;0;0;1];
    newData = [versionNum;newMacAddr;newDateData];
    if opts.verbose
      disp(['MAC address changed: ' inFileID.macStr ...
        ' -> ' opts.defaultMacStr]);
      disp(['Measurement date changed: ' ...
        datestr(datetime(inFileID.time, 'ConvertFrom', 'posixtime')) ...
        ' -> ' datestr(datetime(newDatePosix, 'ConvertFrom', 'posixtime'))]);
    end
  case 204 %meas date
    inDate = dataArray2int(inTag.data);
    if opts.usingMeasDateOffset
      newDatePosix = floor(inDate-24*60*60*opts.measDateOffset);
    else
      newDatePosix = opts.measDateDefault;
    end
    newData = [int2dataArray(newDatePosix);0;0;0;1];
    if opts.verbose
      disp(['Measurement date changed: ' ...
        datestr(datetime(inDate, 'ConvertFrom', 'posixtime')) ...
        ' -> ' datestr(datetime(newDatePosix, 'ConvertFrom', 'posixtime'))]);
    end
  case 206
    if(blockTypeList(end) == 101)
      newData = double(opts.string)';
      if opts.verbose
        disp(['Description of the measurement block changed: ' ...
          char(inTag.data') ' -> ' opts.string]);
      end
    else
      newData = inTag.data;
    end
  case 212
    newData = double(opts.string)';
    if opts.verbose
      disp(['Experimenter changed: ' char(inTag.data') ' -> ' opts.string]);
    end
  case 400
    data = dataArray2int(inTag.data);
    newData = int2dataArray(opts.subjectId);
    if opts.verbose
      disp(['Subject ID changed: ' num2str(data) ' -> ' num2str(opts.subjectId)]);
    end
  case 401
    newData = double(opts.subjectFirstName)';
    if opts.verbose
      disp(['Subject First Name changed: ' char(inTag.data') ' -> ' opts.subjectFirstName]);
    end
  case 402
    newData = double(opts.subjectMiddleName)';
    if opts.verbose
      disp(['Subject Middle Name changed: ' char(inTag.data') ' -> ' opts.subjectMiddleName]);
    end
  case 403
    newData = double(opts.subjectLastName)';
    if opts.verbose
      disp(['Subject Last Name changed: ' char(inTag.data') ' -> ' opts.subjectLastName]);
    end
  case 404
    inBirthDay = dataArray2int(inTag.data);
    inBirthDayPosix = posixtime(datetime(inBirthDay, 'ConvertFrom', 'juliandate'));
    if opts.usingsubjectBirthdayOffset
      newDatePosix = floor(inBirthDayPosix-24*60*60*opts.subjectBirthdayOffset);
    else
      newDatePosix = opts.subjectBirthDayDefault;
    end
    newDateJulian = ceil(juliandate(datetime(newDatePosix, 'convertfrom', 'posixtime')));
    newData = int2dataArray(newDateJulian);
    if opts.verbose
      disp(['Subject birthday changed: ' ...
        datestr(datetime(inBirthDayPosix, 'ConvertFrom', 'posixtime')) ...
        ' -> ' datestr(datetime(newDateJulian, 'ConvertFrom', 'juliandate'))]);
    end
  case 405
    if opts.brute
      data = dataArray2int(inTag.data);
      newData = int2dataArray(opts.subjectDefaultSex);
      if opts.verbose
        disp(['Subject''s sex changed: ' enumSex(data) ' -> ' enumSex(opts.subjectSex)]);
      end
    else
      newData = inTag.data;
    end
  case 406
    if opts.brute
      data = dataArray2int(inTag.data);
      newData = int2dataArray(opts.subjectDfltHandedness);
      if opts.verbose
        disp(['Subject''s handedness changed: ' enumHandedness(data) ' -> ' enumHandedness(opts.subjectHandedness)]);
      end
    else
      newData = inTag.data;
    end
  case 407
    if opts.brute
      data =  floatAsDataArray2double(inTag.data);
      newData = double2floatAsDataArray(opts.subjectWeight);
      if opts.verbose
        disp(['Subject weight changed: ' num2str(data) ' -> ' num2str(opts.subjectWeight)]);
      end
    else
      newData = inTag.data;
    end
  case 408
    if opts.brute
      data = floatAsDataArray2double(inTag.data);
      newData = double2floatAsDataArray(opts.subjectHeight);
      if opts.verbose
        disp(['Subject height changed: ' num2str(data) ' -> ' num2str(opts.subjectHeight)]);
      end
    else
      newData = inTag.data;
    end
  case 409
    newData = double(opts.subjectComment)';
    if opts.verbose
      disp(['Subject Comment changed: ' char(inTag.data') ' -> ' opts.subjectComment]);
    end
  case 410
    newData = double(opts.subjectHisId)';
    if opts.verbose
      disp(['Subject Hospital-ID changed: ' char(inTag.data') ' -> ' opts.subjectHisId]);
    end
  case 500
    if opts.brute
      newData = int2dataArray(opts.projectId);      
      data = dataArray2int(inTag.data);
      if opts.verbose
        disp(['Project ID changed: ' num2str(data) ' -> ' num2str(opts.projectId)]);
      end
    else
      newData = inTag.data;
    end
  case 501
    if opts.brute
      newData = double(opts.projectName)';
      if opts.verbose
        disp(['Project Name changed: ' char(inTag.data') ' -> ' opts.projectName]);
      end
    else
      newData = inTag.data;
    end
  case 502
    if opts.brute
      newData = double(opts.projectAim)';
      if opts.verbose
        disp(['Project Aim changed: ' char(inTag.data') ' -> ' opts.projectAim]);
      end
    end
  case 503
    newData = double(opts.projectPersons)';
    if opts.verbose
      disp(['Project Persons changed: ' char(inTag.data') ' -> ' opts.projectPersons]);
    end
  case 504
    if opts.brute
      newData = double(opts.projectComment)';
      if opts.verbose
        disp(['Project Comment changed: ' char(inTag.data') ' -> ' opts.projectComment]);
      end
    end
  case 2006
    disp(' ');
    disp('WARNING. The input fif file contains MRI data.');
    disp('Beware that a subject''s face can be reconstructed from it');
    disp('This software can not anonymize MRI data, at the moment.');
    disp('Contanct the authors for more information.');
    disp(' ');
  otherwise
    newData = inTag.data;
end

outTag.kind = inTag.kind;
outTag.type = inTag.type;
outTag.size = length(newData);
outTag.next = inTag.next;
outTag.data = newData;

sizeDiff = (outTag.size - inTag.size);

end

function tagDir = add_entry_to_tagDir(tagDir, tag, pos)

tag = rmfield(tag, 'data');
tag = rmfield(tag, 'next');
tag.pos = pos;
tagDir = cat(2, tagDir, tag);

end

function tagDir = add_final_entry_to_tagDir(tagDir)
tag.kind = -1;
tag.type = -1;
tag.size = -1;
tag.pos = -1;
tagDir = cat(2, tagDir, tag);
end

function write_directory(fid, dir, dirpos)
% TAG_INFO_SIZE = 16;
numTags = size(dir, 2);

fseek(fid, dirpos, 'bof');
fwrite(fid, int32(102), 'int32');
fwrite(fid, int32(32), 'int32');
fwrite(fid, int32(16*numTags), 'int32');
fwrite(fid, int32(-1), 'int32');

for i = 1:numTags
  fwrite(fid, int32(dir(i).kind), 'int32');
  fwrite(fid, int32(dir(i).type), 'int32');
  fwrite(fid, int32(dir(i).size), 'int32');
  fwrite(fid, int32(dir(i).pos), 'int32');
end

end

function count = update_pointer(fid, dir, tagKind, newAddr)
TAG_INFO_SIZE = 16;
filePos = ftell(fid);

tagPos = find(tagKind == [dir.kind]', 1);
if ~isempty(tagPos)
  fseek(fid, dir(tagPos).pos+TAG_INFO_SIZE, 'bof');
  count = fwrite(fid, int32(newAddr), 'int32');
else
  count = 0;
end

fseek(fid, filePos, 'bof');
end

function blockTypeList = update_block_type_list(blockTypeList, tag)
if(tag.kind == 104)%block start
  blockType = dataArray2int(tag.data);
  blockTypeList = cat(1, blockTypeList, blockType);
elseif(tag.kind==105)%block end
  try
    blockTypeList(end) = [];
  catch
    warning('The file seems to be broken. There are more close block tags than open block tags!')
  end
end
end

function opts = configure_options(fileName, varargin)

inParams = inputParser;
inParams.KeepUnmatched = true;

addRequired(inParams, 'fileName', @ischar);
[inFilePath, inFileName, inFileExt] = fileparts(fileName);
defaultOutFile = fullfile(inFilePath, [inFileName '_anonymized' inFileExt]);

addParameter(inParams, 'verbose', false, @islogical);
addParameter(inParams, 'output_file', defaultOutFile, @ischar);
addParameter(inParams, 'set_measurement_date_offset', 0, @isPositiveNumericInteger);
addParameter(inParams, 'set_subject_birthday_offset', 0, @isPositiveNumericInteger);
addParameter(inParams, 'delete_input_file_after', false, @islogical);
addParameter(inParams, 'delete_confirmation', true, @islogical);
addParameter(inParams, 'brute', false, @islogical);
addParameter(inParams, 'quiet', false, @islogical);

parse(inParams, fileName, varargin{:});

if ~isempty(fieldnames(inParams.Unmatched))
  disp(' Warning: Extra inputs!');
  disp(inParams.Unmatched);
end

defaultString = 'brainstorm_fiff_anonymizer';
opts = [];
opts.inputFile = inParams.Results.fileName;
opts.verbose = inParams.Results.verbose;
opts.outputFile = inParams.Results.output_file;
opts.measDateOffset = inParams.Results.set_measurement_date_offset;
opts.subjectBirthdayOffset = inParams.Results.set_subject_birthday_offset;
opts.deleteFileAfter = inParams.Results.delete_input_file_after;
opts.deleteConfirmation = inParams.Results.delete_confirmation;
opts.brute = inParams.Results.brute;
opts.quiet = inParams.Results.quiet;
if opts.quiet
  opts.verbose = false;
end

opts.usingMeasDateOffset = ...
  ~any(strcmp(inParams.UsingDefaults, 'set_measurement_date_offset'));
opts.usingsubjectBirthdayOffset = ...
  ~any(strcmp(inParams.UsingDefaults, 'set_subject_birthday_offset'));

opts.measDateDefault = posixtime(datetime(2000, 1, 1, 0, 1, 1));
opts.string = defaultString;
opts.defaultMAC = [0;0;0;0;0;0;0;0];
macStr = [];
for i = 1:6
  macStr = cat(2, macStr, [dec2hex(opts.defaultMAC(i), 2) ':']);
end
opts.defaultMacStr = macStr(1:end-1);

opts.subjectId = 0;
opts.subjectFirstName = defaultString;
opts.subjectMiddleName = 'bst';
opts.subjectLastName = defaultString;
opts.subjectBirthDayDefault = posixtime(datetime(2000, 1, 1, 0, 1, 1));
opts.subjectSex = 0;
opts.subjectHandedness = 0;
opts.subjectWeight = 0;
opts.subjectHeight = 0;
opts.subjectComment = defaultString;
opts.subjectHisId = 'bst';

opts.projectId = 0;
opts.projectName = defaultString;
opts.projectAim = defaultString;
opts.projectPersons = defaultString;
opts.projectComment = defaultString;

end

function r = wrongFifVersion(inTag, fiffver)
%first tag should be an ID tag.
r = false;
%checking for valid fiff file.
if(inTag.kind ~= 100)
  r = true; %we'll assume it is wrong version then.
  warning('Sorry! This is not a valid FIF ID tag.');
else
  %checking for correct version of fif file format
  fileID = parse_fileID_tag(inTag.data);
  if(fileID.version > fiffver)
    r = true;
    warning(['Sorry! This version of fiff_anonymizer only supports' ...
      ' fif files up to version: ' num2str(fiffver)]);
  end
end

end

function i = dataArray2int(data)
  %i = double(typecast(fliplr(uint8(data(:))'), 'int32'));
  i = data(1)*2^24 + data(2)*2^16 + data(3)*2^8 + data(4);
end

function d = int2dataArray(p)
  dd = dec2hex(p,8);
  d = [hex2dec(dd(1:2));hex2dec(dd(3:4));...
       hex2dec(dd(5:6));hex2dec(dd(7:8))];
end

function r = floatAsDataArray2double(data)
  r = typecast(fliplr(uint8(data(:))'), 'single');
end

function data = double2floatAsDataArray(d)
  data = fliplr(typecast(single(d), 'uint8'));
end

function s = enumSex(i)
 sexEnum{1} =  'anonymized';
 sexEnum{2} =  'male';
 sexEnum{3} =  'female';
 s = sexEnum{i+1};
end
 
function h = enumHandedness(i)
  handednessEnum{1} = 'anonymized';
  handednessEnum{2} = 'right';
  handednessEnum{3} = 'left';
  h = handednessEnum{i+1};
end

function test = isPositiveNumericInteger(i)
try
  if ( isnumeric(i)   && ...
       ~isinf(i)      && ...      %mod(i,1) == 0 would also work fine
      (floor(i) == cei(i)) && ... %in these two cases.
      (i > 0) )
    test = true;
  else
    test = false;
  end
catch
  test = false;
end

end
