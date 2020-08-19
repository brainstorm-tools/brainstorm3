function varargout = process_fooof_bands( varargin )
% PROCESS_FOOOF_BANDS: Helper function for FOOOF frequency bands.
%
% USAGE:        strBands = process_fooof_bands('FormatBands', FreqBands)
%               Bands = process_fooof_bands('ParseBands', strBands)
%               FreqBands = process_fooof_bands('Eval', FreqBands)

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
% Authors: Francois Tadel, 2012-2014, Luc Wilson, 2020

eval(macro_method);
end

%% ===== BANDS => STRING =====
function strBands = FormatBands(Bands) %#ok<DEFNU>
    strBands = '';
    for i = 1:size(Bands,1)
        strBands = [strBands, sprintf('%s / %s\n', Bands{i,1}, Bands{i,2})];
    end
end

%% ===== STRING => BANDS =====
function Bands = ParseBands(strBands) %#ok<DEFNU>
    Bands = {};
    if isempty(strtrim(strBands))
        return
    end
    % Split by lines
    lineBand = str_split(strBands, 10);
    % Process each line
    for iBand = 1:length(lineBand)
        % Split line 
        valBand = str_split(lineBand{iBand}, '/\|');
        if (length(valBand) == 2)
            Bands{iBand,1} = strtrim(valBand{1});
            Bands{iBand,2} = strtrim(valBand{2});
        end
    end
end

%% ===== EVAL =====
function Bands = Eval(Bands) %#ok<DEFNU>
    for iBand = 1:size(Bands,1)
        Bands{iBand,2} = eval(['[', Bands{iBand,2}, ']']);
    end
end