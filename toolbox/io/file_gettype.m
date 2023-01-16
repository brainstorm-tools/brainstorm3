function fileType = file_gettype( fileName )
% FILE_GETTYPE: Idenfity a file type based on its fileName.
%
% USAGE:  fileType = file_gettype( fileName )
%         fileType = file_gettype( sMat )
%
% INPUT:
%     - fileName : Full path to file to identify
%     - sMat     : Structure that should be contained in a file
% OUTPUT:
%     - fileType : Brainstorm type (eg. 'subject', 'data', 'anatomy', ...) 

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
% Authors: Francois Tadel, 2008-2022


%% ===== INPUT: FILE =====
if ischar(fileName)
    % Detect links
    if (length(fileName) > 5) && strcmpi(fileName(1:5),'link|')
        fileType = 'link';
        return;
    end
    % Detect spikes directory
    if ~isempty(regexp(fileName, '_\w+_spikes$', 'once'))
        fileType = 'dirspikes';
        return;
    end
    % Initialize possible types and formats to empty lists
    fileType = 'unknown';

    % Get the different file parts : path, name, extension
    [filePath, fileName, fileExt] = bst_fileparts(fileName);
    fileName = lower(fileName);
    fileExt  = lower(fileExt);
    % If file has no extension : don't know what to do
    if (isempty(fileExt))
        return;
    end
    % Replace some standard separators with "_"
    fileName = strrep(fileName, '.', '_');
    fileName = strrep(fileName, '-', '_');
    % Add a '_' at the beginning of the fileName, so that the first word of
    % the fileName can be considered a tag (ex: 'brainstormsubject.mat')
    fileName = ['_' fileName];

    % If it is a Matlab .mat file : look for valid tags in fileName
    if (length(fileExt) >= 4) && (isequal(fileExt(1:4), '.mat'))
        if ~isempty(strfind(fileName, '_data_0ephys'))
            fileType = 'spike';
        elseif ~isempty(strfind(fileName, '_data'))
            fileType = 'data';
        elseif ~isempty(strfind(fileName, '_results'))
            fileType = 'results';
        elseif ~isempty(strfind(fileName, '_linkresults'))
            fileType = 'linkresults';
        elseif ~isempty(strfind(fileName, '_brainstormstudy'))
            fileType = 'brainstormstudy';
        elseif ~isempty(strfind(fileName, '_channel'))
            fileType = 'channel';
        elseif ~isempty(strfind(fileName, '_headmodel'))
            fileType = 'headmodel';
        elseif ~isempty(strfind(fileName, '_noisecov'))
            fileType = 'noisecov';
        elseif ~isempty(strfind(fileName, '_ndatacov'))
            fileType = 'ndatacov';
        elseif ~isempty(strfind(fileName, '_timefreq'))
            fileType = 'timefreq';
        elseif ~isempty(strfind(fileName, '_pdata'))
            fileType = 'pdata';
        elseif ~isempty(strfind(fileName, '_presults'))
            fileType = 'presults';
        elseif ~isempty(strfind(fileName, '_ptimefreq'))
            fileType = 'ptimefreq';
        elseif ~isempty(strfind(fileName, '_pmatrix'))
            fileType = 'pmatrix';
        elseif ~isempty(strfind(fileName, '_brainstormsubject'))
            fileType = 'brainstormsubject';
        elseif ~isempty(strfind(fileName, '_subjectimage'))
            fileType = 'subjectimage';
        elseif ~isempty(strfind(fileName, '_tess'))
            if ~isempty(strfind(fileName, '_cortex'))   % || ~isempty(strfind(fileName, '_brain'))
                fileType = 'cortex';
            elseif ~isempty(strfind(fileName, '_scalp')) || ~isempty(strfind(fileName, '_skin')) || ~isempty(strfind(fileName, '_head'))
                fileType = 'scalp';
            elseif ~isempty(strfind(fileName, '_outerskull')) || ~isempty(strfind(fileName, '_outer_skull')) || ~isempty(strfind(fileName, '_oskull'))
                fileType = 'outerskull';
            elseif ~isempty(strfind(fileName, '_innerskull')) || ~isempty(strfind(fileName, '_inner_skull')) || ~isempty(strfind(fileName, '_iskull'))
                fileType = 'innerskull';
            elseif ~isempty(strfind(fileName, '_skull'))
                fileType = 'outerskull';
            elseif ~isempty(strfind(fileName, '_fibers'))
                fileType = 'fibers';
            elseif ~isempty(strfind(fileName, '_fem'))
                fileType = 'fem';
            else
                fileType = 'tess';
            end
        elseif ~isempty(strfind(fileName, '_res4'))
            fileType = 'res4';
        elseif ~isempty(strfind(fileName, '_dipoles'))
            fileType = 'dipoles';
        elseif ~isempty(strfind(fileName, '_matrix'))
            fileType = 'matrix';
        elseif ~isempty(strfind(fileName, '_proj'))
            fileType = 'proj';
        elseif ~isempty(strfind(fileName, '_scout'))
            fileType = 'scout';
        elseif ~isempty(strfind(fileName, '_videolink'))
            fileType = 'videolink';
        end
    % If file is an image:
    elseif (ismember(fileExt, {'.bmp','.emf','.eps','.jpg','.jpeg','.jpe','.pbm','.pcx','.pgm','.png','.ppm','.tif','.tiff'}))
        fileType = 'image';
    % If file is a video
    elseif (ismember(fileExt, {'.avi','.mpg','.mpeg','.mp4','.mp2','.mkv','.wmv','.divx','.mov'}))
        fileType = 'video';
    end
    
%% ===== INPUT: STRUCTURE =====
elseif isstruct(fileName)
    sMat = fileName;  
    if isfield(sMat, 'F')
        fileType = 'data';
    elseif isfield(sMat, 'ImageGridAmp')
        fileType = 'results';
    elseif isfield(sMat, 'BrainStormSubject')
        fileType = 'brainstormstudy';
    elseif isfield(sMat, 'Channel')
        fileType = 'channel';
    elseif all(isfield(sMat, {'HeadModelType','MEGMethod'}))
        fileType = 'headmodel';
    elseif isfield(sMat, 'NoiseCov')
        if ~isempty(strfind(lower(sMat.Comment), 'noise'))
            fileType = 'noisecov';
        else
            fileType = 'ndatacov';
        end
    elseif isfield(sMat, 'TF')
        fileType = 'timefreq';
    elseif all(isfield(sMat, {'tmap','Type'})) && strcmpi(sMat.Type, 'data')
        fileType = 'pdata';
    elseif all(isfield(sMat, {'tmap','Type'})) && strcmpi(sMat.Type, 'results')
        fileType = 'presults';
    elseif all(isfield(sMat, {'tmap','Type'})) && strcmpi(sMat.Type, 'timefreq')
        fileType = 'ptimefreq';
    elseif all(isfield(sMat, {'tmap','Type'})) && strcmpi(sMat.Type, 'matrix')
        fileType = 'pmatrix';
    elseif isfield(sMat, 'Cortex')
        fileType = 'brainstormsubject';
    elseif isfield(sMat, 'Cube')
        fileType = 'subjectimage';
    elseif isfield(sMat, 'Scout')
        fileType = 'scout';
    elseif isfield(sMat, 'Faces')
        fileType = 'tess';
    elseif isfield(sMat, 'Points')
        fileType = 'fibers';
    elseif isfield(sMat, 'Elements')
        fileType = 'fem';
    elseif isfield(sMat, 'Dipole')
        fileType = 'dipoles';
    elseif isfield(sMat, 'Value')
        fileType = 'matrix';
    elseif isfield(sMat, 'VideoStart')
        fileType = 'videolink';
    elseif isfield(sMat, 'Spikes')
        fileType = 'spike';
    else
        fileType = 'unknown';
    end
else
    fileType = 'unknown';
end

end



