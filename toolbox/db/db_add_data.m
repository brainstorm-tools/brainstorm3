function [sStudy, iItem] = db_add_data(iStudy, FileName, FileMat, iItem)
% DB_ADD_DATA: Add a functional file (recordings, sources, stat, timefreq) to a study
%
% USAGE:  [sStudy, iItem] = db_add_data(iStudy, FileName, FileMat)        : Add a new file to database
%         [sStudy, iItem] = db_add_data(iStudy, FileName, FileMat, iItem) : Replace existing file (delete previous one)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors:  Francois Tadel, 2010

% Parse inputs
if (nargin < 4)
    iItem = [];
end
deletedFile = {};

% Get study
sStudy = bst_get('Study', iStudy);
% Get relative filename
ProtocolInfo = bst_get('ProtocolInfo');
FileName = file_short(FileName);
% Get file type
fileType = file_gettype(FileName);
% Switch according to file type
switch (fileType)
    case {'pdata', 'presults','ptimefreq','pmatrix'}
        % Create new descriptor
        sNew = db_template('Stat');
        sNew.FileName   = FileName;
        sNew.Comment    = FileMat.Comment;
        sNew.Type       = FileMat.Type;
        % Add it to study
        if isempty(iItem)
            iItem = length(sStudy.Stat) + 1;
        else
            deletedFile{end+1} = sStudy.Stat(iItem).FileName;
        end
        sStudy.Stat(iItem) = sNew;
    case 'timefreq'
        % Create new descriptor
        sNew = db_template('Timefreq');
        sNew.FileName = FileName;
        sNew.Comment  = FileMat.Comment;
        sNew.DataFile = FileMat.DataFile;
        sNew.DataType = FileMat.DataType;
        % Add it to study
        if isempty(iItem)
            iItem = length(sStudy.Timefreq) + 1;
        else
            deletedFile{end+1} = sStudy.Timefreq(iItem).FileName;
        end
        sStudy.Timefreq(iItem) = sNew;
    case 'data'
        % Create new descriptor
        sNew = db_template('Data');
        sNew.FileName = FileName;
        sNew.Comment  = FileMat.Comment;
        % DataType
        if isfield(FileMat, 'DataType')
            sNew.DataType = FileMat.DataType;
        else
            sNew.DataType = 'recordings';
        end
        % BadTrial
        sNew.BadTrial = 0;
        % Add it to study
        if isempty(iItem)
            iItem = length(sStudy.Data) + 1;
        else
            deletedFile{end+1} = sStudy.Data(iItem).FileName;
            % Raw files: delete associated .bin file
            if strcmpi(sStudy.Data(iItem).DataType, 'raw')
                BinFile = strrep(sStudy.Data(iItem).FileName, '.mat', '.bin');
                if file_exist(bst_fullfile(ProtocolInfo.STUDIES, BinFile))
                    deletedFile{end+1} = BinFile;
                end
            end
        end
        sStudy.Data(iItem) = sNew;
    case {'results','link'}
        % Create new descriptor
        sNew = db_template('Results');
        sNew.FileName = FileName;
        sNew.Comment  = FileMat.Comment;
        sNew.DataFile = FileMat.DataFile;
        % HeadModelType
        if isfield(FileMat, 'HeadModelType')
            sNew.HeadModelType = FileMat.HeadModelType;
        else
            sNew.HeadModelType = 'surface';
        end
        % Add it to study
        if isempty(iItem)
            iItem = length(sStudy.Result) + 1;
        else
            deletedFile{end+1} = sStudy.Result(iItem).FileName;
        end
        sStudy.Result(iItem) = sNew;
    case 'matrix'
        % Create new descriptor
        sNew = db_template('Matrix');
        sNew.FileName = FileName;
        sNew.Comment  = FileMat.Comment;
        % Add it to study
        if isempty(iItem)
            iItem = length(sStudy.Matrix) + 1;
        else
            deletedFile{end+1} = sStudy.Matrix(iItem).FileName;
        end
        sStudy.Matrix(iItem) = sNew;
end
% Update database
bst_set('Study', iStudy, sStudy);

% Delete replaced file
if ~isempty(deletedFile)
    for i = 1:length(deletedFile)
        file_delete(bst_fullfile(ProtocolInfo.STUDIES, deletedFile{i}), 1);
    end
end


