function varargout = process_swap_headcoils(varargin)
% PROCESS_SWAP_HEADCOILS: Correct channel names for swapped head localization coils.

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
% Authors: Marc Lalancette, 2019

eval(macro_method);
end



function sProcess = GetDescription() %#ok<DEFNU>
    % Description of the process
    sProcess.Comment     = 'Swap head coils (CTF)';
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/HeadMotion#Fixing_swapped_head_coils';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Import', 'Channel file'};
    sProcess.Index       = 52;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw', 'data'};
    sProcess.OutputTypes = {'raw', 'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Options
    sProcess.options.Na.Type    = 'checkbox';
    sProcess.options.Na.Comment = 'Nasion';
    sProcess.options.Na.Value   = 0;
    sProcess.options.Le.Type    = 'checkbox';
    sProcess.options.Le.Comment = 'Left ear';
    sProcess.options.Le.Value   = 0;
    sProcess.options.Re.Type    = 'checkbox';
    sProcess.options.Re.Comment = 'Right ear';
    sProcess.options.Re.Value   = 0;
    sProcess.options.reverse.Type    = 'checkbox';
    sProcess.options.reverse.Comment = 'Reverse order (when swapping all 3 coils)';
    sProcess.options.reverse.Value   = 0;
    %     sProcess.options.display.Type    = 'checkbox';
    %     sProcess.options.display.Comment = 'Display "before" and "after" alignment figures.';
    %     sProcess.options.display.Value   = 0;
    
end



function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
    Na = sProcess.options.Na.Value;
    Le = sProcess.options.Le.Value;
    Re = sProcess.options.Re.Value;
    if Na && Le && Re
        if sProcess.options.reverse.Value
            Comment = [Comment, ': Na<-Le<-Re'];
        else
            Comment = [Comment, ': Na->Le->Re'];
        end
    elseif Na && Le
        Comment = [Comment, ': Na<->Le'];
    elseif Na && Re
        Comment = [Comment, ': Na<->Re'];
    elseif Le && Re
        Comment = [Comment, ': Le<->Re'];
    end
    
end



function OutputFiles = Run(sProcess, sInputs)
    OutputFiles = {sInputs.FileName};
    
    Na = sProcess.options.Na.Value;
    Le = sProcess.options.Le.Value;
    Re = sProcess.options.Re.Value;
    if Na + Le + Re < 2
        bst_report('Warning', sProcess, sInputs, 'Fewer than 2 coils selected, nothing to do.');
        return;
    end
    
    nInFiles = length(sInputs);
    [UniqueChan, iUniqFiles] = unique({sInputs.ChannelFile});
    nFiles = numel(iUniqFiles);
    if nFiles < nInFiles
        bst_report('Warning', sProcess, sInputs, ...
            'Multiple inputs were found for a single channel file. Only the first one will be used for swapping head coils.');
    end
    
    if Na && Le && Re
        if sProcess.options.reverse.Value
            Comment = 'Na<-Le<-Re';
            iBef = 1:12;
            iAft = [5:12, 1:4];
        else
            Comment = 'Na->Le->Re';
            iBef = [5:12, 1:4];
            iAft = 1:12;
        end
    elseif Na && Le
        Comment = 'Na<->Le';
        iBef = 1:8;
        iAft = [5:8, 1:4];
    elseif Na && Re
        Comment = 'Na<->Re';
        iBef = [1:4, 9:12];
        iAft = [9:12, 1:4];
    elseif Le && Re
        Comment = 'Le<->Re';
        iBef = 5:12;
        iAft = [9:12, 5:8];
    end
    
    bst_progress('start', 'Swap head coils', ' ', 0, nFiles);
    for iFile = iUniqFiles(:)' % no need to repeat on same channel file.
        
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        bst_progress('inc', 1);

        % Check the input is CTF.
        DataMat = in_bst_data(sInputs(iFile).FileName, 'Device');
        if ~strcmp(DataMat.Device, 'CTF')
            bst_report('Error', sProcess, sInputs(iFile), ...
                'Swap head coils is currently only available for CTF data.');
            continue;
        end
        
        HluChan = {'HLC0011', 'HLC0012', 'HLC0013', 'HLC0018', ...
            'HLC0021', 'HLC0022', 'HLC0023', 'HLC0028', ...
            'HLC0031', 'HLC0032', 'HLC0033', 'HLC0038'}; % usual order
        [Unused, iHlu] = ismember(HluChan, {ChannelMat.Channel.Name});
        if numel(iHlu) < numel(HluChan)
            bst_report('Error', sProcess, sInputs(iFile), 'Head coil channels not found.');
            continue;
        end
        
        for i = 1:numel(iBef)
            ChannelMat.Channel(iHlu(iBef(i))).Name = HluChan{iAft(i)};
        end
        
        ChannelMat = bst_history('add', ChannelMat, 'edit', ...
            ['Swapped head coils: ', Comment]);

        % Save channel file. Need to save before adjusting because LoadHlu
        % gets the channel info from file.
        bst_save(file_fullpath(sInputs(iFile).ChannelFile), ChannelMat, 'v7');

        %         % Attempt to adjust the initial/reference head position.
        %         [ChannelMat, Failed] = process_adjust_coordinates('AdjustHeadPosition', ...
        %             ChannelMat, sInputs(iFile), sProcess);
        %         if ~Failed
        %             % Save channel file.
        %             bst_save(file_fullpath(sInputs(iFile).ChannelFile), ChannelMat, 'v7');
        %             % Show new alignment.
        %             channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
        %         % else Already noted in report.
        %         end
                    
    end % file loop
    bst_progress('stop');

    OutputFiles = bst_process('CallProcess', 'process_adjust_coordinates', OutputFiles, [], ...
        'reset', 0, 'head', 1, 'bad', 1, 'points', 0, 'remove', 0, 'display', 1);
    
end





