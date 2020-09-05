function OutputFile = file_anonymize(InputFile)
% FILE_ANONYMIZE: Remove all the identification strings from a file.

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
% Authors: Francois Tadel, 2020

OutputFile = [];

% Find file in databas
[sStudy, iStudy] = bst_get('AnyFile', InputFile);
if ~isempty(sStudy)
    FileType = file_gettype(InputFile);
    InputFile = file_short(InputFile);
else
    error('Not supported yet.');
end
% Progress bar
bst_progress('start', 'Anonymize', 'Anonymizing file...');
% Switch depending on file type
switch FileType
    case 'data'
        isRaw = ~isempty(strfind(InputFile, '_0raw'));
        if isRaw
            % Load link to raw file
            DataMat = in_bst_data(InputFile, 'F');
            RawFile = DataMat.F.filename;
            % Output file name
            anonTag = '_anon';
            [fPath, fBase, fExt] = bst_fileparts(RawFile);
            NewRawFile = bst_fullfile(fPath, [fBase, anonTag, fExt]);
            % Anonymize file
            switch (DataMat.F.format)
                case 'FIF'
                    % Anonymize FIF file
                    fiff_anonymizer(RawFile, 'output_file', NewRawFile);
                    ImportOptions.ChannelAlign    = 0;
                    ImportOptions.ChannelReplace  = 0;
                    ImportOptions.EventsMode      = 'ignore';
                    ImportOptions.DisplayMessages = 0;
                    % Read new anonymized header
                    sFileNew = in_fopen_fif(NewRawFile, ImportOptions);
                otherwise
                    error(['File format not supported yet: ' DataMat.F.format]);
            end
            % If the new file doesn't exit: didn't work
            if ~file_exist(NewRawFile)
                error(['Anonymized file was not created: ' NewRawFile]);
            end
            % Duplicate initial raw folder
            NewRawFolder = process_duplicate('DuplicateCondition', bst_fileparts(InputFile), anonTag);
            % Get raw data file in this folder
            [sStudyNew, iStudyNew] = bst_get('StudyWithCondition', NewRawFolder);
            OutputFile = file_fullpath(sStudyNew.Data(1).FileName);
            % Update file structure
            NewDataMat = in_bst_data(OutputFile);
            NewDataMat.Comment = strrep(NewDataMat.Comment, 'Link to raw file', 'Raw');
            NewDataMat.Comment = [NewDataMat.Comment, ' | ', strrep(anonTag, '_', '')];
            NewDataMat.F = sFileNew;
            bst_save(OutputFile, NewDataMat, 'v6');
            % Update database
            sStudyNew.Data(1).Comment = NewDataMat.Comment;
            bst_set('Study', iStudyNew, sStudyNew);
            % Update tree
            panel_protocols('UpdateTree');
        else
            error('Not supported yet.');
        end
    otherwise
        error('Not supported yet.');
end
% Close progress bar
bst_progress('stop');

