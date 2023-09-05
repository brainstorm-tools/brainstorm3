function [sStudy, iItem] = db_add_data(iStudy, FileName, FileMat, iItem)
% DB_ADD_DATA: Add a functional file (recordings, sources, stat, timefreq) to a study
%
% USAGE:  [sStudy, iItem] = db_add_data(iStudy, FileName, FileMat)        : Add a new file to database
%         [sStudy, iItem] = db_add_data(iStudy, FileName, FileMat, iItem) : Replace existing file (delete previous one)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors:  Francois Tadel, 2010-2018

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
            % Make file comment unique
            if ~isempty(sStudy.Stat)
                Comment = file_unique(sNew.Comment, {sStudy.Stat.Comment});
                % Modify input file
                if ~isequal(Comment, sNew.Comment)
                    save(file_fullpath(FileName), 'Comment', '-append');
                    sNew.Comment = Comment;
                end
            end
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
            % Make file comment unique
            if ~isempty(sStudy.Timefreq)
                % Get the time-frequency files that have reference file
                iSameParent = find(cellfun(@(c)isequal(c, sNew.DataFile), {sStudy.Timefreq.DataFile}));
                % If there are files with the same parent: make it unique within this group
                if ~isempty(iSameParent)
                    Comment = file_unique(sNew.Comment, {sStudy.Timefreq(iSameParent).Comment});
                    % Modify input file
                    if ~isequal(Comment, sNew.Comment)
                        save(file_fullpath(FileName), 'Comment', '-append');
                        sNew.Comment = Comment;
                    end
                end
            end
        else
            deletedFile{end+1} = sStudy.Timefreq(iItem).FileName;
        end
        sStudy.Timefreq(iItem) = sNew;
    case {'data', 'spike'}
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
            % Make file comment unique
            if ~isempty(sStudy.Data)
                Comment = file_unique(sNew.Comment, {sStudy.Data.Comment});
                % Modify input file
                if ~isequal(Comment, sNew.Comment)
                    save(file_fullpath(FileName), 'Comment', '-append');
                    sNew.Comment = Comment;
                end
            end
        else
            deletedFile{end+1} = sStudy.Data(iItem).FileName;
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
            % Make file comment unique
            if ~isempty(sStudy.Result)
                % Get the time-frequency files that have reference file
                iSameParent = find(cellfun(@(c)isequal(c, sNew.DataFile), {sStudy.Result.DataFile}));
                % If there are files with the same parent: make it unique within this group
                if ~isempty(iSameParent)
                    Comment = file_unique(sNew.Comment, {sStudy.Result(iSameParent).Comment});
                    % Modify input file
                    if ~isequal(Comment, sNew.Comment)
                        save(file_fullpath(FileName), 'Comment', '-append');
                        sNew.Comment = Comment;
                    end
                end
            end
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
            % Make file comment unique
            if ~isempty(sStudy.Matrix)
                Comment = file_unique(sNew.Comment, {sStudy.Matrix.Comment});
                % Modify input file
                if ~isequal(Comment, sNew.Comment)
                    save(file_fullpath(FileName), 'Comment', '-append');
                    sNew.Comment = Comment;
                end
            end
        else
            deletedFile{end+1} = sStudy.Matrix(iItem).FileName;
        end
        sStudy.Matrix(iItem) = sNew;
    case 'headmodel'
        % Create new descriptor
        sNew = db_template('HeadModel');
        sNew.FileName      = FileName;
        sNew.Comment       = FileMat.Comment;
        sNew.HeadModelType = FileMat.HeadModelType;
        sNew.MEGMethod     = FileMat.MEGMethod;
        sNew.EEGMethod     = FileMat.EEGMethod;
        sNew.ECOGMethod    = FileMat.ECOGMethod;
        sNew.SEEGMethod    = FileMat.SEEGMethod;
        % Add it to study
        if isempty(iItem)
            iItem = length(sStudy.HeadModel) + 1;
            % Make file comment unique
            if ~isempty(sStudy.HeadModel)
                Comment = file_unique(sNew.Comment, {sStudy.HeadModel.Comment});
                % Modify input file
                if ~isequal(Comment, sNew.Comment)
                    save(file_fullpath(FileName), 'Comment', '-append');
                    sNew.Comment = Comment;
                end
            end
        else
            deletedFile{end+1} = sStudy.HeadModel(iItem).FileName;
        end
        sStudy.HeadModel(iItem) = sNew;
        % Make it the default head model
        sStudy.iHeadModel = iItem;
end
% Update database
bst_set('Study', iStudy, sStudy);

% Delete replaced file
if ~isempty(deletedFile)
    for i = 1:length(deletedFile)
        file_delete(bst_fullfile(ProtocolInfo.STUDIES, deletedFile{i}), 1);
    end
end


