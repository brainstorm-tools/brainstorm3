function out_figure_movie( hFig, defaultFile, movieType, OPTIONS )
% OUT_FIGURE_MOVIE: Build a movie of the temporal evolution of the target figure.
% 
% USAGE:  out_figure_movie( hFig, defaultFile, movieType [, OPTIONS] )
%
% INPUT:
%     - hFig        : handle to figure to capture
%     - defaultFile : file name or default directory 
%     - movieType   : {'time', 'horizontal', 'vertical', 'allfig'}
%     - OPTIONS     : optional structure 
%          |- Duration    : number of seconds of video
%          |- FrameRate   : movie frame rate in fps
%          |- Quality     : [0,100]
%          |- TimeRange   : [tStart,tStop], time window to extract (all time definition if not specified)

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
% Authors: Francois Tadel, 2008-2019

global prevTimeSelection;
                          
%% ===== CHECK INPUTS =====
% === DEFAULT FILENAME ===
if isempty(defaultFile) || isdir(defaultFile)
    % If specified file is a directory : ask user which file
    movieDefaultDir  = defaultFile;
    % Get the default filename (from the window title)
    wndTitle = get(hFig, 'Name');
    if isempty(wndTitle)
        movieDefaultFile = 'movie.avi';
    else
        movieDefaultFile = [file_standardize(wndTitle), '.avi'];
        movieDefaultFile = strrep(movieDefaultFile, '__', '_');
    end
    % Get filename
    movieDefaultFile = bst_fullfile(movieDefaultDir, movieDefaultFile);
    MovieFile = java_getfile('save', 'Save video as...', movieDefaultFile, 'single', 'files', ...
                             {{'.avi'}, 'Microsoft AVI (*.avi)', 'AVI'}, 1);
    if isempty(MovieFile)
        return
    end
    % Save new default export path
    LastUsedDirs = bst_get('LastUsedDirs');
    LastUsedDirs.ExportImage = bst_fileparts(MovieFile);
    bst_set('LastUsedDirs', LastUsedDirs);
% If filename is not a valid file : exit with an error
elseif ~file_exist(bst_fileparts(defaultFile))
    error('Directory "%s" does not exist.', defaultFile);
else
    MovieFile = defaultFile;
end

% === MOVIE OPTIONS ===
if (nargin < 4)
    if strcmpi(movieType, 'time') || strcmpi(movieType, 'allfig')
        % == DEFAULT TIME ==
        % Get figure description
        [hFig, iFig, iDS] = bst_figures('GetFigure', hFig);
        if isempty(iDS)
            return
        end
        % Get time vector for this Dataset
        TimeVector = bst_memory('GetTimeVector', iDS, [], 'UserTimeWindow');
        % Is there any pre-existing and valid time selection
        if ~isempty(prevTimeSelection) && (prevTimeSelection(1) >= TimeVector(1)) && (prevTimeSelection(1) <= TimeVector(end))
            TimeBounds = prevTimeSelection;
        else
            TimeBounds = [TimeVector(1), TimeVector(end)];
        end
        
        % Ask user some parameters
        userOptions = java_dialog('input', {'Start time (s):', 'Stop time (s):', 'Video duration (in seconds):', 'Frame rate (in fps):', 'Quality [0-100]:'}, ...
                                            'Video', [], {num2str(TimeBounds(1),'%1.3f'), num2str(TimeBounds(2),'%1.3f'), ...
                                                               num2str(10), num2str(15), num2str(75)});
        if isempty(userOptions) || isempty(str2num(userOptions{1})) || isempty(str2num(userOptions{2})) || isempty(str2num(userOptions{3})) || isempty(str2num(userOptions{4})) || isempty(str2num(userOptions{5}))
            return
        end
        OPTIONS.TimeRange(1) = str2num(userOptions{1});
        OPTIONS.TimeRange(2) = str2num(userOptions{2});
        OPTIONS.Duration  = str2num(userOptions{3});
        OPTIONS.FrameRate = str2num(userOptions{4});
        OPTIONS.Quality   = str2num(userOptions{5});
        % Store in global variable this selection
        prevTimeSelection = OPTIONS.TimeRange;
    else
        % Ask user some parameters
        userOptions = java_dialog('input', {'Movie duration (in seconds):', 'Frame rate (in fps):', 'Quality [0-100]:'}, 'Video', [], {num2str(10), num2str(15), num2str(75)});
        if isempty(userOptions) || isempty(str2num(userOptions{1})) || isempty(str2num(userOptions{2})) || isempty(str2num(userOptions{3}))
            return
        end
        OPTIONS.Duration  = str2num(userOptions{1});
        OPTIONS.FrameRate = str2num(userOptions{2});
        OPTIONS.Quality   = str2num(userOptions{3});
    end
end
nbSamples = round(OPTIONS.Duration .* OPTIONS.FrameRate);


%% ===== PREPARE MOVIE =====
% Remove file if it already exist
if file_exist(MovieFile)
    clear mex
    file_delete(MovieFile, 1);
end
% Movie Type
switch lower(movieType)
    % TIME COURSE MOVIE
    case {'time', 'allfig'}
        TimeRange = OPTIONS.TimeRange;
        % Check time bounds
        TimeRange(1) = max(TimeRange(1), TimeVector(1));
        TimeRange(2) = min(TimeRange(2), TimeVector(end));
        if (TimeRange(1) >= TimeRange(2))
            error('Invalid time range.');
        end
        % Create the contact sheet time vector
        samplesTime = TimeVector(bst_closest(linspace(TimeRange(1), TimeRange(2), nbSamples), TimeVector));

    % SPATIAL ROTATION
    case {'horizontal', 'vertical'}
        incDegree = 360 / nbSamples;
end

%% ===== CREATE FILE =====
% Try to use the VideoWrite class
try
    % 'Archival': Motion JPEG 2000 file with lossless compression
    % 'Motion JPEG AVI': Compressed AVI file using Motion JPEG codec
    % 'Motion JPEG 2000': Compressed Motion JPEG 2000 file
    % 'MPEG-4': Compressed MPEG-4 file with H.264 encoding (systems with Windows 7 or Mac OS X 10.7 and later)

    % Create the object (use the default AVI compression)
    hWriter = VideoWriter(MovieFile);
    % Open the file
    hWriter.Quality   = OPTIONS.Quality;
    hWriter.FrameRate = OPTIONS.FrameRate;
    hWriter.open();
    % Keep track of the writer that is used
    isVideoWriter = 1;
        
% Use the old "avifile" function instead
catch
    isVideoWriter = 0;
    % Display warning message
    disp(['BST> Warning: The VideoWriter function is not available in this version of Matlab.' 10 ...
          'BST>          Using the older avifile function instead (no compression).' 10 ...
          'BST>          For compressing your video files, you must run Windows 7 or MacOS 10.7 (or newer),' 10 ...
          'BST>          and Matlab R2010b (or newer) or the compiled version of Brainstorm.']);
    % Create file
    try 
        hMovie = avifile(MovieFile, ...
            'compression', 'none', ...
            'fps',         OPTIONS.FrameRate, ...
            'quality',     100);
    catch
        bst_error(['Cannot create new file: ' MovieFile], 'Video');
        return
    end
end

%% ===== ALL FIGURES: GET THE WORKSPACE =====
% Get the figures to capture
if strcmpi(movieType, 'allfig')
    hFigSnap = bst_figures('GetAllFigures');
else
    hFigSnap = hFig;
end
% Get screen definition
ScreenDef = bst_get('ScreenDef');
% Single screen (TODO: Handle the cases where the two screens are organized in different ways)
firstPos = get(hFigSnap(1), 'Position');
if (length(ScreenDef) == 1)
    ZoomFactor = ScreenDef(1).zoomFactor;
elseif (firstPos(1) < ScreenDef(1).matlabPos(1) + ScreenDef(1).matlabPos(3))
    ZoomFactor = ScreenDef(1).zoomFactor;
else
    ZoomFactor = ScreenDef(2).zoomFactor;
end
        
% Get the coordinates of all the figures to capture
if (length(hFigSnap) > 1)
    % Get the coordinates
    for iFig = 1:length(hFigSnap)
        posSnap(iFig,:) = round(get(hFigSnap(iFig), 'Position') .* ZoomFactor);
    end
    % Inialize the final image
    posWorkspace = [min(posSnap(:,1)), min(posSnap(:,2)), max(posSnap(:,1)+posSnap(:,3))-min(posSnap(:,1)), max(posSnap(:,2)+posSnap(:,4))-min(posSnap(:,2))];
    % Standardize positions to the workspace
    posSnap(:,1) = posSnap(:,1) - posWorkspace(1) + 1;
    posSnap(:,2) = posSnap(:,2) - posWorkspace(2) + 1;
    % Convert Y axis from bottom to top 
    posSnap(:,2) = posWorkspace(4) - posSnap(:,2) - posSnap(:,4) + 2;
    % Initialize image to save
    img = zeros(posWorkspace(4), posWorkspace(3), 3, 'uint8');
end


%% ===== LOOP ON SAMPLES =====
hAxes = findobj(hFig, 'Tag', 'Axes3D');
hLight = findobj(hFig, 'Tag', 'FrontLight');
for iSample = 1:nbSamples
    % Update image
    switch lower(movieType)
        case {'time', 'allfig'}
            % Set new time value
            panel_time('SetCurrentTime', samplesTime(iSample));  
        case 'horizontal'
            camorbit(hAxes, -incDegree, 0, 'camera');
            camlight(hLight, 'headlight');
        case 'vertical'
            camorbit(hAxes, 0, -incDegree, 'camera');
            camlight(hLight, 'headlight');
    end
    % Extract figure display
    if (length(hFigSnap) == 1)
        img = out_figure_image(hFigSnap);
    else
        for iFig = 1:length(hFigSnap)
            % Capture image: adds the time label only on the selected image
            if (hFigSnap(iFig) == hFig)
                tmpImg = out_figure_image(hFigSnap(iFig), [], 'time');
            else
                tmpImg = out_figure_image(hFigSnap(iFig), [], []);
            end
            img(posSnap(iFig,2)+(0:size(tmpImg,1)-1), posSnap(iFig,1)+(0:size(tmpImg,2)-1), :) = tmpImg;
        end
    end
    % Add image to movie
    if isVideoWriter
        hWriter.writeVideo(img);
    else
        hMovie = addframe(hMovie, img);
    end
end
% Close movie
if isVideoWriter
    hWriter.close();
else
    hMovie = close(hMovie);
end
% Display message : Done.
java_dialog('msgbox', 'Video successfully saved.', 'Video');

