function ctf_rename_ds(originalDs, newDsName, newSessionFolder, isAnonymize, subjectID, sessionDate)
% ctf_rename_ds: Renames and/or anonymizes a CTF dataset (.ds)
%
% USAGE:    ctf_rename_ds(originalDs.ds, newDsName.ds);
%           ctf_rename_ds(originalDs.ds, newDsName.ds, newSessionFolder);
%           ctf_rename_ds(originalDs.ds, newDsName.ds, [], 1, subjectID, sessionDate);
%           ctf_rename_ds(originalDs.ds, newDsName.ds, [], 1, subjectID);
%           ctf_rename_ds(originalDs.ds, newDsName.ds, [], 1);
%
% INPUT:    OriginalDs - full path to original ds
%           newSessionFolder - path to new session folder if different from original
%           newDsName - new name of ds folder
%           newDsName = ['sub-' SubjectID '_ses-' SessionID '_task-' TaskName '_run-' RunNumb '_meg.ds'];
%           isAnonymize = 0 or 1 (0 = keep all orig fields, 1 = remove identifying fields)
%           subjectID = new ID or [] = use subject ID from newDsName (chars before the first underscore)
%           sessionDate = new date (dd-MMM-yyyy) or [] = use orig dates
%
% Note: anonymization will remove all subject identifying information from
% the header files (names, dates, collection description, operator, run titles)
% Birthdate is changed to 01/01/1900 and subject sex is set to 'other'
%
% OUTPUT:   new dataset

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors:  Elizabeth Bock, 2017-2018

if nargin < 3
    newSessionFolder = [];
end
if nargin < 4
    isAnonymize = 0;
end
if nargin < 5
    subjectID = [];
end
if nargin < 6
    sessionDate = [];
end

[origPath,origName] = fileparts(originalDs);
[tmp,newName] = fileparts(newDsName);
if isempty(newSessionFolder)
    newPath = origPath;
else
    newPath = newSessionFolder;
end

% Find the path of the study for renaming PATH OF DATASET entries
% STUDYNAME/sub-xxx/ses-xxx/meg/*.ds
sepInd = regexp(newPath, filesep);
studySession = newPath(sepInd(end-3)+1:end);
if isempty(subjectID)
    subjectID = newPath(sepInd(end-2)+1:sepInd(end-1)-1);
end

% if a new date is given, prepare the different formats for different files
% res4date = '12-May-1891'; %dd-MMM-yyyy
% infodsdate = '18910512114600'; %yyyyMMddhhmmss
% acqdate = '12/05/1891'; %dd/mm/yyyy

res4date = [];
acqdate = [];
infodsdate = [];
if ~isempty(sessionDate)
    t=datetime(sessionDate,'InputFormat','dd-MMM-yyyy');
    res4date = sessionDate;
    acqdate = char(datetime(t,'Format','dd/MM/yyyy'));
    infodsdate = char(datetime(t,'Format','yyyyMMdd'));
end

%% rename the parent ds folders
newDs = fullfile(newPath, [newName '.ds']);
% Must check if exists, otherwise would move a duplicate inside newDs.
if exist(newDs, 'dir')
  % Move all files inside dataset.
  file_move(fullfile(originalDs, '*'), newDs);
  % Delete empty original dataset folder.
  rmdir(originalDs);
else
  % Rename dataset folder.
  file_move(originalDs, newDs);
end

%% rename files inside parent folder
files = dir(fullfile(newDs, [origName '*']));
for iFiles = 1:length(files)
    repName = regexprep(files(iFiles).name, origName, newName);
    file_move(fullfile(newDs,files(iFiles).name), fullfile(newDs,repName));
end

%% ClassFile.cls
% change PATH OF DATASET
clsFile = dir(fullfile(newDs, '*.cls'));
if ~isempty(clsFile)
    fid  = fopen(fullfile(newDs, clsFile.name),'r');
    f=fread(fid,'*char')';
    fclose(fid);
    newlineInd = regexp(f,'\n');
    oldstr = f(newlineInd(1)+1:newlineInd(2));
    f = strrep(f,oldstr,fullfile(studySession, [newName '.ds']));
    fid  = fopen(fullfile(newDs, clsFile.name),'w');
    fprintf(fid,'%s',f);
    fclose(fid);
end

%% MarkerFile.mrk
% change PATH OF DATASET
mrkFile = dir(fullfile(newDs, '*.mrk'));
if ~isempty(mrkFile)
    fid  = fopen(fullfile(newDs, mrkFile.name),'r');
    f=fread(fid,'*char')';
    fclose(fid);
    newlineInd = regexp(f,'\n');
    oldstr = f(newlineInd(1)+1:newlineInd(2));
    f = strrep(f,oldstr,fullfile(studySession, [newName '.ds']));
    fid  = fopen(fullfile(newDs, mrkFile.name),'w');
    fprintf(fid,'%s',f);
    fclose(fid);
end

%% *.acq
% for anon: run title, date, time and description
if isAnonymize || ~isempty(acqdate)
    acqFile = dir(fullfile(newDs, '*.acq'));
    if ~isempty(acqFile)
        % read the file
        acqTag=readCPersist(fullfile(newDs,acqFile.name),0);
        
        if isAnonymize
        nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({acqTag.name},'_run_title')));
        acqTag(nameTag(1)).data = '';
        nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({acqTag.name},'_run_description')));
        acqTag(nameTag(1)).data = '';
        end
        
        if ~isempty(acqdate)
            nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({acqTag.name},'_run_date')));
            acqTag(nameTag(1)).data = acqdate;
        end
        % save changes
        writeCPersist(fullfile(newDs,acqFile.name),acqTag);
    end
end

%% *.hist
if isAnonymize
    % for anon: run title, date, time
    % delete the .hist file
    delete(fullfile(newDs, '*.hist'));
else
    % append new dataset name?
    histFile = dir(fullfile(newDs, '*.hist'));
    if ~isempty(histFile)
        fid = fopen(fullfile(newDs, histFile.name),'r');
        f=fread(fid,'*char')';
        fclose(fid);
        f = strrep(f,origName,newName);
        fid  = fopen(fullfile(newDs, histFile.name),'w');
        fprintf(fid,'%s',f);
        fclose(fid);

    end
end

%% *.infods
% {'_PATIENT_NAME_FIRST';'_PATIENT_NAME_MIDDLE';'_PATIENT_NAME_LAST';'_PATIENT_ID';'_PATIENT_BIRTHDATE';'_PATIENT_SEX'}
% {'_PROCEDURE_ACCESSIONNUMBER';'_PROCEDURE_STARTEDDATETIME'}
infoDs = dir(fullfile(newDs, '*.infods'));
if ~isempty(infoDs)
    % read file
    infoTag=readCPersist(fullfile(newDs,infoDs.name),0);

    nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_PATIENT_NAME_FIRST')));
    infoTag(nameTag(1)).data = '';
    nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_PATIENT_NAME_MIDDLE')));
    infoTag(nameTag(1)).data = '';
    nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_PATIENT_NAME_LAST')));
    infoTag(nameTag(1)).data = '';
    nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_PATIENT_ID')));
    infoTag(nameTag(1)).data = subjectID;
    if isAnonymize
        nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_PATIENT_BIRTHDATE')));
        infoTag(nameTag(1)).data = '19000101000000';
        nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_PATIENT_SEX')));
        infoTag(nameTag(1)).data = 2;
        nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_PROCEDURE_ACCESSIONNUMBER')));
        infoTag(nameTag(1)).data = '';
        nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_PROCEDURE_TITLE')));
        infoTag(nameTag(1)).data = '';
    end
    if ~isempty(infodsdate)
        nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_PROCEDURE_STARTEDDATETIME')));
        tt = infoTag(nameTag(1)).data(end-5:end); % get the time
        infodsdate = [infodsdate tt]; % put new date and time together (yyyyMMddhhmmss)
        infoTag(nameTag(1)).data = infodsdate;
        nameTag = find(cellfun(@(c)~isempty(find(c,1)), regexp({infoTag.name},'_DATASET_COLLECTIONDATETIME')));
        infoTag(nameTag(1)).data = infodsdate;
    end
    % save changes        
    writeCPersist(fullfile(newDs,infoDs.name),infoTag)
end

%% *.res4
% binary file that contains dataset info including the following
% identifying fields:
% nfSetUp.nf_run_name, nfSetUp.nf_run_title, nfSetUp.nf_instruments, nfSetUp.nf_collect_descriptor, nfSetUp.nf_subject_id, nfSetUp.nf_operator
if isAnonymize   
    % Check to see if the date needs to be changed
    if ~isempty(res4date)
        res4File = dir(fullfile(newDs, '*.res4'));
        res4Info = build_sidecar_readres4(fullfile(newDs,res4File.name));
        data_time = res4Info.data_time;
        data_date = res4date;
        
        ctf_anonymize(newDs, subjectID, '', '', data_time, data_date);
    else
        ctf_anonymize(newDs, subjectID);
    end
    
    % remove the .bak files
    delete(fullfile(newDs, '*.bak'));
end

%% .newds
if isAnonymize
    % not needed
    delete(fullfile(newDs, '*.newds'));
end

%% other files that do not need to be accessed
% default.de

% *.eeg
% text file with list of EEG channels and locations (if updated)

% *.hc
% text file with head position information

% *.meg4
% binary file that contains the MEG sensor data

end


function ctf_anonymize(ds_dir, subject_id, run_title, operator, data_time, data_date)

% List res4 files
dslist = dir(fullfile(ds_dir, '*.res4'));
if isempty(dslist)
    error('Cannot find res4 file.');
end
% Get res4 file
res4_file = fullfile(ds_dir, dslist(1).name);
disp(['Editing file: ' res4_file]);

% Open .res4 file (Big-endian byte ordering)
[fid,message] = fopen(res4_file, 'r+', 'b');
if (fid < 0)
    error(message);
end

% Subject id
if (nargin >= 2) && ~isempty(subject_id)
    res4_write_string(fid, subject_id, 1712, 32);
    disp(['   > subject_id = ' subject_id]);
end
% Run title
if (nargin >= 3) && ~isempty(run_title)
    res4_write_string(fid, run_title, 1392, 256);
    disp(['   > run_title  = ' run_title]);
end
% Operator
if (nargin >= 4) && ~isempty(operator)
    res4_write_string(fid, operator, 1744, 32);
    disp(['   > operator   = ' operator]);
end
% Time
if (nargin >= 5) && ~isempty(data_time)
    res4_write_string(fid, data_time, 778, 255);
    disp(['   > data_time  = ' data_time]);
end
% Date
if (nargin >= 6) && ~isempty(data_date)
    res4_write_string(fid, data_date, 1033, 255);
    disp(['   > data_date  = ' data_date]);
end

% Close file
fclose(fid);

end

% ===== WRITE STRING IN RES4 =====
function res4_write_string(fid, value, offset, n)
    % Trim string
    if (length(value) > n)
        value = value(1:n);
    end
    % Create padded string
    str = char(zeros(1,n));
    str(1:length(value)) = value;
    % Write string
    if (fseek(fid, offset, 'bof') == -1)
        fclose(fid);
        error('Cannot go to byte #%d.', offset);
    end
    if (fwrite(fid, str, 'char') < n)
        fclose(fid);
        error('Cannot write data to file.');
    end
end

