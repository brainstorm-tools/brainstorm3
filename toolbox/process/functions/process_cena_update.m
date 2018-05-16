function varargout = process_cena_update( varargin )
% process_cena_update: downloads/installs the CENA microsegmentation tools
% Copyright 2014-2015 The University of Chicago
% License: https://hpenlaboratory.uchicago.edu/page/cena-user-agreement
% For more information see: https://hpenlaboratory.uchicago.edu/page/cena
% For support contact cenasupport@uchicago.edu


% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Author: Robin Weiss, 2015

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'CENA : Install/Update';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'External', 'Microstates'};
    sProcess.Index       = 2000;
    sProcess.isSeparator = 0;
    sProcess.Description = 'https://hpenlaboratory.uchicago.edu/page/cena';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'import'};
    sProcess.OutputTypes = {'import'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 0;
    
    % Definition of the options
    sProcess.options.desc.Type = 'label';
    sProcess.options.desc.Comment = ['This process will install/update the CENA plugin for microstate analysis: <BR>Chicago Electrical NeuroImaging Analytics<BR><BR>', ...
                                     'For more information about CENA, see:<BR> https://hpenlaboratory.uchicago.edu/page/cena<BR><BR>'];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    OutputFiles = {};
    
    % set URLs and files based on distro being updated/downloaded
    url = 'http://projects.rcc.uchicago.edu/cacioppos/cena/pub/CENA-pub-latest.tar';
    tarFile = 'CENA-pub-latest.tar';
    cenaSrcDir = 'process_cena_pub_src';
    cenaSrcFiles = 'process_cena_pub*';
    logoFile = 'process_cena_pub_src_logo.png';
    
    % Agree to license terms
    while true
        res = java_dialog('question', ...
                           sprintf(['The Chicago Electrical NeuroImaging Analytics (CENA) plugin is available\n', ...
                                    'to registered users only.  To register for access, select the "Register" option below.\n\n', ...
                                    'By downloading the Chicago Electrical NeuroImaging Analytics (CENA) plugin\n', ...
                                    'you are accepting and agreeing to the terms of the CENA software license.']), ...
                           'Chicago Electrical NeuroImaging Analytics (CENA)', [], {'I Agree', 'View License', 'Register', 'Cancel'}, 'Cancel');
        if strcmp(res,'View License')
            web('https://hpenlaboratory.uchicago.edu/page/cena-user-agreement','-browser');
        elseif strcmp(res,'Register')
            web('https://hpenlaboratory.uchicago.edu/content/cena-request-form','-browser');
        elseif strcmp(res,'I Agree')
            break;
        elseif isempty(res) || strcmp(res,'Cancel')
            return
        end
    end

    
    % get password from user
    passwd = java_dialog('input', ...
                         sprintf(['Please enter your download passphrase for CENA.\n', ...
                                  'You should have received this via email after registration.\n\n', ...
                                  'Download Passphase:']), ...
                         'Enter Passphrase');
    if isempty(passwd)
        return
    end

    % remember current directory
    currDir = pwd;
    
    bst_progress('start', 'Chicago Electrical NeuroImaging Analytics (CENA)', 'Installing CENA...');
    
    % go to the plugin directory
    cd(bst_fullfile(bst_get('BrainstormUserDir'), 'process'));
    
    % try to download the latest cena zip
    try
        urlwrite(url, tarFile,'Authentication','Basic','Username','hpms','Password',passwd);
    catch ME
        if (strcmp(ME.identifier,'MATLAB:urlwrite:BasicAuthenticationFailed'))
            java_dialog('error', sprintf('Authentication Error.  Wrong passphrase?'), 'Error');
            return;
        else
            java_dialog('error', sprintf('Error in UrlWrite: %s\n\nContact cenasupport@uchicago.edu', ME.identifier), 'Error');
            return;
        end
    end

    % if we managed to get the latest cena zip
    if (exist(tarFile,'file'))
        try
            % delete existing CENA stuff
            try 
                rmdir(cenaSrcDir,'s');
                delete(cenaSrcFiles);
            catch
            end

            % unpack
            if ispc
                untar(tarFile);
            else
                system(['tar -xf ' tarFile]);
            end

            % remove archive file
            delete(tarFile);

            % display info screen
            cena_text = ['<html><body>',....
                        '<center><img src="file:', ...
                        bst_fullfile(bst_get('BrainstormUserDir'), 'process', logoFile), ...
                        '", width="275" height="192"></center>', ...
                        '<center>&copy; 2014-2015 University of Chicago</center>', ...
                        '<center><p>Thank you for downloading the Chicago Electrical NeuroImaging Analytics (CENA) toolbox.</p></center>', ...
                        '<center><p>CENA functions are now available in the Microstates section of the Brainstorm Pipeline Editor.</p></center>', ...
                        '<center><p>For support contact: cenasupport@uchicago.edu</p></center>', ...
                        '<p><b>References to cite:</b></p>', ...
                        '<p>Cacioppo, S., Weiss, R. M. Runesha, H. B., & Cacioppo, J. T. (2014). ', ...
                        'Dynamic Spatiotemporal Brain Analyses using High-Performance Electrical NeuroImaging: ', ...
                        'Theoretical Framework and Validation. <i>Journal of Neuroscience Methods, 238</i>: 11-34. ', ...
                        'doi: 10.1016/j.jneumeth.2014.09.009.</p>',...
                        '<p>Cacioppo, S., & Cacioppo, J. T. (2015). ', ...
                        'Dynamic spatiotemporal brain analyses using high-performance electrical neuroimaging, ', ...
                        'Part II: A Step-by-Step Tutorial. <i>Journal of Neuroscience Methods, 256</i>: 184-197. ', ...
                        'pii: S0165-0270(15)00337-4. doi: 10.1016/j.jneumeth.2015.09.004.</p>', ...
                        '</body></html>'];
 
            % Create a figure with a scrollable JEditorPane
            hFigure = figure(...
                        'position', [0, 0, 800, 600], ...
                        'resize', 'on', ...
                        'Name', 'Chicago Electrical NeuroImaging Analytics (CENA)', ...
                        'NumberTitle', 'off', ...
                        'MenuBar', 'none', ...
                        'ToolBar', 'none', ...
                        'units','pixels', ...
                        'color', [1 1 1]);
            movegui(hFigure,'center');
            
            je = javax.swing.JEditorPane('text/html', cena_text);
            je.setEditable(0);
            jp = javax.swing.JScrollPane(je);
            [hcomponent, hcontainer] = javacomponent(jp, [], hFigure);
            set(hcontainer, 'units', 'normalized', 'position', [0,0.1,1,0.9],'parent',hFigure);
            
            labelStr = '<html><i>CENA License Agreement';
            cbStr = 'web(''https://hpenlaboratory.uchicago.edu/page/cena-user-agreement'',''-browser'');';
            uicontrol('string',labelStr,'units', 'normalized','position',[0.05, 0.025, 0.2, 0.05],'callback',cbStr,'parent',hFigure);

            labelStr = '<html><i>CENA Homepage';
            cbStr = 'web(''https://hpenlaboratory.uchicago.edu/page/cena'',''-browser'');';
            uicontrol('string',labelStr,'units', 'normalized','position',[0.4, 0.025, 0.2, 0.05],'callback',cbStr,'parent',hFigure);

            labelStr = '<html><b>Close';
            uicontrol('string',labelStr,'units', 'normalized','position',[0.75, 0.025, 0.2, 0.05],'callback',@(h,ev)close(hFigure),'parent',hFigure);
            
        catch ME
            java_dialog('error', sprintf('Error During CENA Unpack: %s\n\nPlease contact cenasupport@uchicago.edu', ME.identifier), 'Error');
        end
    end
    
    bst_progress('stop');
    
    % go back to currDir
    cd(currDir);
    
    % clear cached functions
    clear functions;
    
end



