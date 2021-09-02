function varargout = bst_navigator( varargin )
% BST_NAVIGATOR: Navigation through the Brainstorm database.
%
% USAGE : bst_navigator( 'DbNavigation', action, iDataSets ) : Process only the selected datasets
%         bst_navigator( 'DbNavigation', action )            : Process all the loaded datasets
%         bst_navigator( 'CreateNavigatorMenu', jMenuNavigator)
%
% INPUT : action    : possible values {'NextData', 'NextSubject', 'NextCondition', 'NextResult', 'Previous...'}
%         iDataSets : indices of GlobalData.DataSet array

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
% Authors: Francois Tadel, 2008-2015

eval(macro_method);
end


%% ===== NAVIGATION =====
function DbNavigation( action, iDataSets )
    global GlobalData mutexNavigator timerNavigator;
    % ===== MUTEX =====
    % Use a mutex to prevent the function from being executed more than once at the same time
    if isempty(mutexNavigator) || (mutexNavigator > 1)
        % Entrance accepted
        timerNavigator = tic;
        mutexNavigator = 0;
    else
        % Entrance rejected (another call is not finished,and was call less than 1 seconds ago)
        if ~isempty(timerNavigator)
            mutexNavigator = toc(timerNavigator);
        else
            mutexNavigator = toc;
        end
        disp('Call to bst_navigator() ignored...');
        return
    end

    % ===== PARSE INPUTS =====
    % If no DataSets are specified : process all datasets
    if (nargin < 2)
        iDataSets = 1:length(GlobalData.DataSet);
    end
    % Interpret action
    action = lower(action);
    if ~isempty(strfind(action, 'next'))
        moveDirection = 1;
        action = strrep(action, 'next', '');
    elseif ~isempty(strfind(lower(action), 'previous'))
        moveDirection = -1;
        action = strrep(action, 'previous', '');
    else
        moveDirection = 0;
    end
    % Get protocol information
    ProtocolSubjects = bst_get('ProtocolSubjects');

    
%% ===== FOR EACH DATA SET =====
    iDSclose = [];
    for iDS = iDataSets
        % ===== CHECK DATASET =====
        % Two necessary conditions : have a SubjectFile defined, and have at least one figure displayed
        if isempty(GlobalData.DataSet(iDS).SubjectFile) || isempty(GlobalData.DataSet(iDS).Figure)
            % Closing all datasets figures
            % close([GlobalData.DataSet(iDS).Figure.hFigure]);
            continue
        end
        % Save modifications
        if GlobalData.DataSet(iDS).Measures.isModified
            panel_record('SaveModifications', iDS);
        end

        % ===== GET DATASET INFORMATION =====
        % === SUBJECT ===
        [sOldSubject, iOldSubject] = bst_get('Subject', GlobalData.DataSet(iDS).SubjectFile);
        % === STUDY ===
        if isempty(GlobalData.DataSet(iDS).StudyFile)
            isNoStudyFile = 1;
        else
            isNoStudyFile = 0;
            [sOldStudy, iOldStudy] = bst_get('Study', GlobalData.DataSet(iDS).StudyFile);
            if isempty(sOldStudy)
                isNoStudyFile = 1;
            end
        end
        % === DATA ===
        if isempty(GlobalData.DataSet(iDS).DataFile)
            isNoDataFile = 1;
        else
            isNoDataFile = 0;
            [tmp__, tmp__, iOldData] = bst_get('DataFile', GlobalData.DataSet(iDS).DataFile);
            if isempty(iOldData)
                isNoDataFile = 1;
            end
        end

        % ===== GET NEW LOCATION =====
        isSubjectFileChanged = 0;
        isStudyFileChanged   = 0;
        isDataFileChanged    = 0;
        isResultsFileChanged = 0;
        waitMsg = '';
        % Switch according to action
        switch lower(action)     
            % ===== SUBJECT =====
            case 'subject'
                % === NEW SUBJECT ===
                % Get next/previous subject
                iNewSubject = iOldSubject + moveDirection;
                if (iNewSubject <= 0) || (iNewSubject > length(ProtocolSubjects.Subject))
                    continue
                end
                % Switching to next subject
                sNewSubject = bst_get('Subject', iNewSubject);
                newSubjectName = ProtocolSubjects.Subject(iNewSubject).Name;
                newSubjectFile = ProtocolSubjects.Subject(iNewSubject).FileName;
                isSubjectFileChanged = 1;
                % === NEW STUDY ===
                % If study file is defined
                if ~isNoStudyFile 
                    % Get study with NEW subject AND OLD condition
                    newConditionPath = bst_fullfile(newSubjectName, sOldStudy.Condition{:});
                    [sNewStudy, iNewStudy] = bst_get('StudyWithCondition', newConditionPath);
                    % If no study was found
                    if isempty(sNewStudy)
                        continue
                    end
                    isStudyFileChanged = 1;
                else
                    iNewStudy = [];
                    sNewStudy = [];
                end
                % === NEW DATA ===
                % If a DataFile is defined
                if ~isNoDataFile
%                     % If data index is not valid anymore
%                     if (iOldData > length(sNewStudy.Data))
%                         continue
%                     end
%                     iNewData = iOldData;
                    % Cannot switch to an empty folder
                    if isempty(sNewStudy.Data)
                        continue;
                    end
                    % Always the first file of the new condition
                    iNewData = 1;
                    sNewData = sNewStudy.Data(iNewData);
                    % Cannot switch to a continuous raw file
                    if strcmpi(sNewData.DataType, 'raw')
                        continue;
                    end
                    % Display progress bar
                    waitMsg = ['Switching to subject #' num2str(iNewSubject) ': "' newSubjectName '"...' ];  
                    % Ask to update the current datafile 
                    isDataFileChanged = 1;
                end

            % ===== CONDITION =====
            case 'condition'
                % === NEW SUBJECT ===
                sNewSubject = sOldSubject;
                newSubjectName = sNewSubject.Name;
                newSubjectFile = sNewSubject.FileName;
                % === NEW STUDY ===
                % If study file is defined
                if ~isNoStudyFile
                    % Get all the conditions available for the current subject
                    availableConditions = bst_get('ConditionsForSubject', sOldStudy.BrainStormSubject);
                    % Find current condition in conditions list
                    iOldCond = [];
                    for i=1:length(availableConditions)
                        if isequal(availableConditions{i}, sOldStudy.Condition{1})
                            iOldCond = i;
                            break;
                        end
                    end
                    if isempty(iOldCond)
                        continue;
                    end
                    % Get next/previous condition
                    iNewCond = iOldCond + moveDirection;
                    if (iNewCond <= 0) || (iNewCond > length(availableConditions))
                        continue
                    end
                    % Get study with NEW subject AND OLD condition
                    newConditionPath = bst_fullfile(newSubjectName, availableConditions{iNewCond});
                    [sNewStudy, iNewStudy] = bst_get('StudyWithCondition', newConditionPath);
                    % If no study was found
                    if isempty(sNewStudy)
                        continue
                    end
                    isStudyFileChanged = 1;
                end
                % === NEW DATA ===
                % If a DataFile is defined
                if ~isNoDataFile
%                     % If data index is not valid anymore
%                     if (iOldData > length(sNewStudy.Data))
%                         continue
%                     end
%                     iNewData = iOldData;
                    % Cannot switch to an empty folder
                    if isempty(sNewStudy.Data)
                        continue;
                    end
                    % Always the first file of the new condition
                    iNewData = 1;
                    sNewData = sNewStudy.Data(iNewData);
                    % Cannot switch to a continuous raw file
                    if strcmpi(sNewData.DataType, 'raw')
                        continue;
                    end
                    % Display progress bar
                    waitMsg = sprintf('Switching to condition "%s"...', newConditionPath);
                    % Ask to update the current datafile 
                    isDataFileChanged = 1;
                end

            % ===== DATA =====
            case 'data'
                % If DataFile or StudyFile is not defined
                % => Changing Data cannot have consequences : go to next DataSet
                if isNoStudyFile || isNoDataFile
                    continue
                end
                % === NEW STUDY ===  
                sNewStudy   = sOldStudy;
                iNewStudy   = iOldStudy;
                % === NEW SUBJECT ===
                sNewSubject = sOldSubject;
                newSubjectFile = sNewSubject.FileName;

                % ===== DATA LISTS =====
                % Get standardized comments
                listComments = cellfun(@str_remove_parenth, {sOldStudy.Data.Comment}, 'UniformOutput', 0);
                % Remove empty matrices
                iEmpty = cellfun(@isempty, listComments);
                if ~isempty(iEmpty)
                    listComments(iEmpty) = {''};
                end
                % Group comments
                [tmp,tmp,iData2List] = unique(listComments);
                % If current file is in a group of trials and not the last one
                iList = iData2List(iOldData);
                % Move to the next one in the trial group
                if (moveDirection == 1) && (nnz(iData2List(iOldData+1:end) == iList) > 0)
                    iNewData = iOldData + find(iData2List(iOldData+1:end) == iList, 1, 'first');
                % Move to the pervious one in the trial group
                elseif (moveDirection == -1) && (nnz(iData2List(1:iOldData-1) == iList) > 0)
                    iNewData = find(iData2List(1:iOldData-1) == iList, 1, 'last');
                % Else go to the next/previous file in the .Data structure
                else
                    iNewData = iOldData + moveDirection;
                end
                
                % === NEW DATA ===
                % Is action valid ?
                if (iNewData <= 0) || (iNewData > length(sOldStudy.Data))
                    continue
                end
                sNewData = sNewStudy.Data(iNewData);
                % Cannot switch to a continuous raw file
                if strcmpi(sNewData.DataType, 'raw')
                    continue;
                end
                % Display progress bar
                waitMsg = sprintf('Switching to data file #%d: "%s"...', iNewData, sNewData.Comment);
                % Ask to update the current datafile
                isDataFileChanged = 1;

            % ===== RESULT =====
            case 'results'
                % If DataFile or StudyFile is not defined
                % => Changing Results cannot have consequences : go to next DataSet
                if isNoStudyFile || isNoDataFile
                    continue;
                end
                % Current ResultsFiles changed
                isResultsFileChanged = 1;
                % But associated data file did not change
                sNewSubject = sOldSubject;
                newSubjectFile = sNewSubject.FileName;
                sNewStudy = sOldStudy;
                sNewData  = sNewStudy.Data(iOldData);
                % Waiting message
                switch (moveDirection)
                    case 1
                        waitMsg = 'Switching to next results file...';
                    case -1
                        waitMsg = 'Switching to previous results file...';
                end
            otherwise
                bst_error(['Invalid action: "' action '"']);
                return
        end

%% ===== UPDATE GLOBAL STRUCTURES =====
        % === COLLAPSE PREVIOUS NODE ===
        if isSubjectFileChanged
            panel_protocols('CollapseAncestor', 'subject');
        elseif isStudyFileChanged
            panel_protocols('CollapseAncestor', 'study');
        elseif isDataFileChanged
            panel_protocols('CollapseAncestor', 'data');
        end

        % === DATAFILE CHANGED ===
        if isDataFileChanged
            % If other DataSets already exist for the new DataFile, unload them
            iOldDS = bst_memory('GetDataSetData', sNewData.FileName);
            if ~isempty(iOldDS)
                bst_memory('UnloadDataSets', iOldDS);
            end
            % Empty loaded data
            GlobalData.DataSet(iDS).Measures = db_template('Measures');
            % Select new data in tree
            %panel_protocols('SelectNode', [], 'data', iNewStudy, iNewData);
            panel_protocols('SelectNode', [], sNewData.FileName);
        % === STUDY CHANGED ===
        elseif isStudyFileChanged
            % Select new data in tree (for the SUBJECTS and STUDIES exploration modes)
            panel_protocols('SelectStudyNode', iNewStudy);
        % === SUBJECT CHANGED ===
        elseif isSubjectFileChanged
            % Select new data in tree (for the SUBJECTS and STUDIES exploration modes)
            panel_protocols('SelectNode', [], 'subject', iNewSubject, -1);
            panel_protocols('SelectNode', [], 'studysubject', -1, iNewSubject);
        end        

        % === UPDATE DATASET ===
        GlobalData.DataSet(iDS).SubjectFile = newSubjectFile;
        % StudyFile
        if ~isNoStudyFile
            GlobalData.DataSet(iDS).StudyFile = sNewStudy.FileName;        
        end
        % DataFile
        if ~isNoDataFile
            GlobalData.DataSet(iDS).DataFile = sNewData.FileName;
            % Old time window
            oldTime = GlobalData.UserTimeWindow.Time;
            % Force data reload
            bst_memory('LoadDataFile', sNewData.FileName, 1, 0);
            % If the time was modified
            if any(abs(GlobalData.DataSet(iDS).Measures.Time - GlobalData.UserTimeWindow.Time) > 1e-6)
                % Change the current time window
                GlobalData.UserTimeWindow.Time            = GlobalData.DataSet(iDS).Measures.Time;
                GlobalData.UserTimeWindow.SamplingRate    = GlobalData.DataSet(iDS).Measures.SamplingRate;
                GlobalData.UserTimeWindow.NumberOfSamples = GlobalData.DataSet(iDS).Measures.NumberOfSamples;
                % Change current time if necessary
                if (GlobalData.UserTimeWindow.CurrentTime < GlobalData.UserTimeWindow.Time(1)) || (GlobalData.UserTimeWindow.CurrentTime > GlobalData.UserTimeWindow.Time(2))
                    panel_time('SetCurrentTime', GlobalData.UserTimeWindow.Time(1));
                % Update time panel
                elseif any(abs(oldTime - GlobalData.UserTimeWindow.Time) > 1e-6)
                    panel_time('UpdatePanel');
                end
                % Close all the other datasets
                iDSclose = setdiff(1:length(GlobalData.DataSet), iDS);
            end
        else
            % Reset UserTimeWindow
            GlobalData.UserTimeWindow.Time            = [];
            GlobalData.UserTimeWindow.SamplingRate    = [];
            GlobalData.UserTimeWindow.NumberOfSamples = 0;
        end
        % === CHANNEL FILE ===
        isUpdatedChannelFile = 0;
        if ~isempty(iNewStudy)
            % Get old channel file
            oldChannelFile = GlobalData.DataSet(iDS).ChannelFile;
            % Get new channel
            sNewChannel = bst_get('ChannelForStudy', iNewStudy);
            % If ChannelFile changed
            if ~isempty(sNewChannel) && ~file_compare(sNewChannel.FileName, oldChannelFile)
                newChannelFile = sNewChannel.FileName;
                isUpdatedChannelFile = 1;
                % Update GlobalData structure
                GlobalData.DataSet(iDS).ChannelFile = newChannelFile;
                % Load new channel file
                ChannelMat = in_bst_channel(newChannelFile);
                GlobalData.DataSet(iDS).Channel         = ChannelMat.Channel;
                GlobalData.DataSet(iDS).MegRefCoef      = ChannelMat.MegRefCoef; 
                GlobalData.DataSet(iDS).Projector       = ChannelMat.Projector;
                GlobalData.DataSet(iDS).IntraElectrodes = ChannelMat.IntraElectrodes;
            end
        end

        
        % === GET NEW RESULTS ===
        % Get results loaded in DataSet
        if ~isempty(GlobalData.DataSet(iDS).Results)
            oldResultsFiles = {GlobalData.DataSet(iDS).Results.FileName};
        else
            oldResultsFiles = {};
        end
        % New results
        newResultsFiles = cell(1, length(oldResultsFiles));
        if (isDataFileChanged || isResultsFileChanged) && ~isempty(oldResultsFiles)
            % Unload all DataSet results
            bst_memory('UnloadDataSetResult', iDS, 1:length(GlobalData.DataSet(iDS).Results));

            % For each old ResultsFile, build the new ResultsFile (or [] if no equivalent)
            for i=1:length(oldResultsFiles)       
                % Get old result file indice in sOldStudy
                [tmp__, tmp__, iOldResult] = bst_get('ResultsFile', oldResultsFiles{i});
                % Get old list of available results in previous sOldStudy
                [tmp__, tmp__, iOldAvailableResults] = bst_get('ResultsForDataFile', sOldStudy.Result(iOldResult).DataFile, iOldStudy);
                % Get indice of old result file in available results
                iOldResultInAvailable = find(iOldAvailableResults == iOldResult);

                % === RESULTS NAVIGATION ===
                if isResultsFileChanged
                    % Data file did not change
                    iNewAvailableResults = iOldAvailableResults;
                    % Get next or previous result
                    iNewResultInAvailable = iOldResultInAvailable + moveDirection;
                    % If requested ResultsFile is NOT available
                    if (iNewResultInAvailable <= 0) || (iNewResultInAvailable > length(iOldAvailableResults))
                        iNewResultInAvailable = [];
                    end
                % === DATA/STUDY NAVIGATION ===
                else
                    % Get all the results available for the new DataFile
                    [tmp__, tmp__, iNewAvailableResults] = bst_get('ResultsForDataFile', sNewData.FileName, iNewStudy);
                    % If equivalent ResultsFile is found for new data
                    if (iOldResultInAvailable <= length(iNewAvailableResults))
                        iNewResultInAvailable = iOldResultInAvailable;
                    else
                        iNewResultInAvailable = [];
                    end
                end

                % If a new results file was found
                if ~isempty(iNewResultInAvailable)
                    iNewResult = iNewAvailableResults(iNewResultInAvailable);
                    newResultsFiles{i} = sNewStudy.Result(iNewResult).FileName;
                else
                    newResultsFiles{i} = [];
                end
            end
        end
        
        
%% ===== UPDATE FIGURES =====
        % Process each figure : update or close it
        iFig = 1;
        isDSUnloaded = 0;
        while ~isDSUnloaded && (iDS <= length(GlobalData.DataSet)) && (iFig <= length(GlobalData.DataSet(iDS).Figure))
            Figure = GlobalData.DataSet(iDS).Figure(iFig);
            isFigureRemoved = 0;
            % Update figure appdata
            setappdata(Figure.hFigure, 'SubjectFile', GlobalData.DataSet(iDS).SubjectFile);
            if ~isNoStudyFile
                setappdata(Figure.hFigure, 'StudyFile', GlobalData.DataSet(iDS).StudyFile);
            end
            if ~isNoDataFile
                setappdata(Figure.hFigure, 'DataFile', GlobalData.DataSet(iDS).DataFile);
            end

            % Switch according to figure type
            switch(Figure.Id.Type)
                % === DATA TIME SERIES ===
                case 'DataTimeSeries'
                    if ~isDataFileChanged
                        % Nothing to do
                    elseif ~isempty(Figure.Id.Modality) && (Figure.Id.Modality(1) ~= '$')
                        % Display progress bar
                        bst_progress('start', 'Database navigator', waitMsg);
                        % Update sensors selected in the figure
                        GlobalData.DataSet(iDS).Figure(iFig).SelectedChannels = bst_figures('GetChannelsForFigure', iDS, iFig);
                        % Update TsInfo structure
                        if ~isNoDataFile
                            TsInfo = getappdata(Figure.hFigure, 'TsInfo');
                            if ~isempty(TsInfo) && isfield(TsInfo, 'FileName') && ~isempty(TsInfo.FileName)
                                TsInfo.FileName = GlobalData.DataSet(iDS).DataFile;
                                setappdata(Figure.hFigure, 'TsInfo', TsInfo);
                            end
                        end
                        % Update "isStatic" status
                        setappdata(Figure.hFigure, 'isStatic', (GlobalData.DataSet(iDS).Measures.NumberOfSamples <= 2));
                        % Reload figure
                        bst_figures('ReloadFigures', Figure.hFigure, 0);
                    else
                        isFigureRemoved = 1;
                    end

                % === RESULTS TIME SERIES ===  
                case 'ResultsTimeSeries'
                    % Get the results list that is displayed in this figure
                    oldFigRes = getappdata(Figure.hFigure, 'ResultsFiles');
                    % If no or more than one results file : close figure
                    if (length(oldFigRes) ~= 1) || isempty(oldResultsFiles)
                        isFigureRemoved = 1;
                    else
                        % Get new results file for this results file
                        iNewRes = find(file_compare(oldResultsFiles, oldFigRes{1}));
                        newFigRes = newResultsFiles{iNewRes};
                        % If cannot switch
                        if isempty(newFigRes) 
                            isFigureRemoved = 1;
                        % Else : update display
                        else
                            % Update figure appdata
                            setappdata(Figure.hFigure, 'ResultsFiles', {newFigRes});
                            setappdata(Figure.hFigure, 'ResultsFile', newFigRes);
                            % Remove figure's unique ID that prevents from writing over this figure
                            GlobalData.DataSet(iDS).Figure(iFig).Id.SubType = '';
                            % Display progress bar
                            bst_progress('start', 'Database navigator', waitMsg);
                            % Call display function again
                            view_scouts({newFigRes}, 'SelectedScouts');
                        end
                    end

                % === RESULTS TIME SERIES ===  
                case 'Topography'
                    if isDataFileChanged
                        % Display progress bar
                        bst_progress('start', 'Database navigator', waitMsg);
                        % Call plot function again for new DataFile
                        view_topography(GlobalData.DataSet(iDS).DataFile, Figure.Id.Modality, Figure.Id.SubType);
                    end 

                % === 3D FIGURES ===  
                case '3DViz'
                    % Get the kind of data represented in this window
                    TessInfo = getappdata(Figure.hFigure, 'Surface');
                    % === PROCESS SURFACES ===
                    for iTess = 1:length(TessInfo)
                        % Get old surface file
                        oldSurfaceFile = TessInfo(iTess).SurfaceFile;
                        % Get new surface file
                        fieldName = ['i' TessInfo(iTess).Name];
                        if (isfield(sNewSubject, fieldName) && ~isempty(sNewSubject.(fieldName)))
                            newSurfaceFile = sNewSubject.Surface(sNewSubject.(fieldName)).FileName;
                        % If old surface type is not available for new subject
                        else
                            % Do not process this surface
                            continue
                        end

                        % === SURFACE CHANGED ===
                        if ~file_compare(oldSurfaceFile, newSurfaceFile)
                            isSurfaceChanged = 1;
                        else
                            isSurfaceChanged = 0;
                        end

                        % === DATA CHANGED ===
                        if ~isempty(TessInfo(iTess).DataSource.Type)
                            % Switch according to type of data on the surface
                            switch (TessInfo(iTess).DataSource.Type)
                                case 'Data'
                                    if isDataFileChanged
                                        % Update Surface description
                                        TessInfo(iTess).DataSource.FileName = sNewStudy.Data(iNewData).FileName;
                                        setappdata(Figure.hFigure, 'Surface', TessInfo);
                                    end
                                case 'Source'
                                    if isResultsFileChanged || isDataFileChanged
                                        % Get new results file for this results file
                                        iNewRes = find(file_compare(oldResultsFiles, TessInfo(iTess).DataSource.FileName));
                                        % If cannot switch
                                        if isempty(iNewRes) || isempty(newResultsFiles{iNewRes(1)})
                                            isFigureRemoved = 1;
                                        % Else : update display
                                        else
                                            % Make sure that only one result is found
                                            iNewRes = iNewRes(1);
                                            newFigRes = newResultsFiles{iNewRes};
                                            % Reset the maximum values for this surface
                                            TessInfo(iTess).DataMinMax = [];
                                            % Update Surface description
                                            TessInfo(iTess).DataSource.FileName = newFigRes;
                                            setappdata(Figure.hFigure, 'Surface', TessInfo);
                                        end
                                    end  
                            end 
                            if ~isFigureRemoved
                                % Display progress bar
                                bst_progress('start', 'Database navigator', waitMsg);
                                % View new surface / new data on surface
                                view_surface_data(TessInfo(iTess).SurfaceFile, TessInfo(iTess).DataSource.FileName, Figure.Id.Modality);
                            end
                            
                        % === SURFACE CHANGED / NO DATA ===
                        elseif isSurfaceChanged
                            % Display progress bar
                            bst_progress('start', 'Database navigator', waitMsg);
                            % Display new surface
                            view_surface(newSurfaceFile);
                            % Remove previous surface
                            panel_surface('RemoveSurface', Figure.hFigure, iTess);
                        end
                    end
                    % === PROCESS SENSORS ===
                    if isUpdatedChannelFile
                        % Get the elements to be displayed
                        isMarkers = ~isempty(Figure.Handles.hSensorMarkers);
                        isLabels  = ~isempty(Figure.Handles.hSensorLabels);
                        % Update channels display
                        %view_channels(GlobalData.DataSet(iDS).ChannelFile, Figure.Id.Modality, isMarkers, isLabels);
                        figure_3d('ViewSensors', Figure.hFigure, isMarkers, isLabels);
                    end
                    
                % === FREQ DISPLAYS ===
                case {'Timfreq', 'Spectrum', 'Pac', 'Image'}
                    isFigureRemoved = 1;
                    
                % === CONNECTIVITY ===
                case 'Connect'
                    isFigureRemoved = 1;
                    
                % Other types of windows: just close them
                otherwise
                    isFigureRemoved = 1;
            end

            % If close request for this figure
            if isFigureRemoved
                % If it is the last DataSet figure => DataSet will be unloaded
                isDSUnloaded = (length(GlobalData.DataSet(iDS).Figure) <= 1);
                % Close figure
                close(Figure.hFigure);
                % Do not increment the figure => A figure was deleted, so the next figure has the same indice
            else
                % Go to next figure
                iFig = iFig + 1;
            end
        end
    end
    % Unload some datasets
    if ~isempty(iDSclose)
    	bst_memory('UnloadDataSets', iDSclose);
    end
    % Update events lists
    panel_record('UpdatePanel');
    % Hide progress bar
    bst_progress('stop');
    % Release mutex 
    mutexNavigator = [];
end



%% ====== CREATE NAVIGATOR MENU ======
function CreateNavigatorMenu(jMenuNavigator) %#ok<DEFNU>
    import java.awt.event.KeyEvent;
    import javax.swing.KeyStroke;
    import org.brainstorm.icon.*;
    % Create items
    jItemPrevSubj = gui_component('MenuItem', jMenuNavigator, [], 'Previous subject',   IconLoader.ICON_PREVIOUS_SUBJECT,   [], @(h,ev)DbNavigation('PreviousSubject'));
    jItemNextSubj = gui_component('MenuItem', jMenuNavigator, [], 'Next subject',       IconLoader.ICON_NEXT_SUBJECT,       [], @(h,ev)DbNavigation('NextSubject'));
    jMenuNavigator.addSeparator();
    jItemPrevCond = gui_component('MenuItem', jMenuNavigator, [], 'Previous condition', IconLoader.ICON_PREVIOUS_CONDITION, [], @(h,ev)DbNavigation('PreviousCondition'));
    jItemNextCond = gui_component('MenuItem', jMenuNavigator, [], 'Next condition',     IconLoader.ICON_NEXT_CONDITION,     [], @(h,ev)DbNavigation('NextCondition'));
    jMenuNavigator.addSeparator();
    jItemPrevData = gui_component('MenuItem', jMenuNavigator, [], 'Previous data file', IconLoader.ICON_PREVIOUS_DATA,      [], @(h,ev)DbNavigation('PreviousData'));
    jItemNextData = gui_component('MenuItem', jMenuNavigator, [], 'Next data file',     IconLoader.ICON_NEXT_DATA,          [], @(h,ev)DbNavigation('NextData'));
    % Set keyboards shortcuts
    jItemNextSubj.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_F1), 0)); % F1
    jItemNextCond.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_F2), 0)); % F2
    jItemNextData.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_F3), 0)); % F3
    jItemPrevSubj.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_F1), KeyEvent.SHIFT_MASK)); % SHIFT+F1
    jItemPrevCond.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_F2), KeyEvent.SHIFT_MASK)); % SHIFT+F2
    jItemPrevData.setAccelerator(KeyStroke.getKeyStroke(int32(KeyEvent.VK_F3), KeyEvent.SHIFT_MASK)); % SHIFT+F3
end

        
        
        
