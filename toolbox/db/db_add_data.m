function [sStudy, iItem] = db_add_data(iStudy, FileName, FileMat, iItem)
% DB_ADD_DATA: Add a functional file (recordings, sources, stat, timefreq) to a study
%
% USAGE:  [sStudy, iItem] = db_add_data(iStudy, FileName, FileMat)        : Add a new file to database
%         [sStudy, iItem] = db_add_data(iStudy, FileName, FileMat, iItem) : Replace existing file (delete previous one)

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
% Authors:  Francois Tadel, 2010-2018

% Parse inputs
if (nargin < 4)
    iItem = [];
end
deletedFile = {};

% Get relative filename
ProtocolInfo = bst_get('ProtocolInfo');
FileName = file_short(FileName);
% Get file type
fileType = file_gettype(FileName);

% Create new descriptor
sNew = db_template('FunctionalFile');
sNew.Study    = iStudy;
sNew.Type     = fileType;
sNew.FileName = FileName;
sNew.Name     = FileMat.Comment;

% Switch according to file type
switch (fileType)
    case {'pdata', 'presults','ptimefreq','pmatrix'}
        sNew.Type    = 'stat';
        sNew.SubType = FileMat.Type;
        
    case 'timefreq'
        sNew.ExtraStr1 = FileMat.DataFile;
        sNew.ExtraStr2 = FileMat.DataType;
        
    case 'data'
        % DataType
        if isfield(FileMat, 'DataType')
            sNew.SubType = FileMat.DataType;
        else
            sNew.SubType = 'recordings';
        end
        % BadTrial
        sNew.ExtraNum = 0;
        
    case {'results','link'}
        sNew.Type  = 'result';
        sNew.ExtraStr1 = FileMat.DataFile;
        % HeadModelType
        if isfield(FileMat, 'HeadModelType')
            sNew.ExtraStr2 = FileMat.HeadModelType;
        else
            sNew.ExtraStr2 = 'surface';
        end
end

% Add it to study
sqlConn = sql_connect();
if isempty(iItem)
    % Make file comment unique
    queryCond = struct('Study', iStudy, 'Type', sNew.Type);
    
    % Special case for timefreq and result file: get unique file name out
    % of files with same reference file (DataFile).
    if ismember(sNew.Type, {'timefreq', 'result'})
        queryCond.ExtraStr1 = sNew.ExtraStr1;
    end
    
    sFuncFiles = db_get(sqlConn, 'FunctionalFile', queryCond, 'Name');
    if ~isempty(sFuncFiles)
        Comment = file_unique(sNew.Name, {sFuncFiles.Name});
        % Modify input file
        if ~isequal(Comment, sNew.Name)
            save(file_fullpath(FileName), 'Comment', '-append');
            sNew.Name = Comment;
        end
    end
    
    % Insert in database
    db_set(sqlConn, 'FunctionalFile', sNew);
else
    % Delete replaced file
    sFuncFileOld = db_get(sqlConn, 'FunctionalFile', iItem, 'FileName');
    if ~isempty(sFuncFileOld)
        file_delete(bst_fullfile(ProtocolInfo.STUDIES, sFuncFileOld.FileName), 1);
    end
    
    % Update database
    db_set(sqlConn, 'FunctionalFile', sNew, iItem);
end
sql_close(sqlConn);

% Get study only if necessary
if nargout > 0
    sStudy = bst_get('Study', iStudy);
end
