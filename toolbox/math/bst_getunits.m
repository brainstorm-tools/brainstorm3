function [valScaled, valFactor, valUnits] = bst_getunits( val, DataType, FileName )
% BST_GETUNITS: Get in which units is expressed a value.
%
% USAGE:  [valScaled, valFactor, valUnits] = bst_getunits(val, DataType, FileName=[]);
%
% INPUT:
%    - val       : Value to analyze
%    - DataType  : Type of data in the value "val". Possible strings: 
%                  'EEG', 'MEG', 'MEG MAG', 'MEG GRAD', 'ECOG', 'SEEG', '$MEG', '$EEG', '$ECOG', '$SEEG', 'results', 'sources', 'source', 'stat', ...
% OUTPUT:
%    - valScaled : value in the detected units (val * valFactor)
%    - valFactor : factor to convert val -> valScaled
%    - valUnits  : string that represents the units ('\muV', 'fT', 'pA.m', etc.)

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

% Check if there is something special in the filename
if (nargin >= 3) && ~isempty(FileName)
    % Detecting sLORETA source files
    if ismember(lower(DataType), {'results', 'sources', 'source'}) && ~isempty(strfind(lower(FileName), 'sloreta'));
        DataType = 'sloreta';
    end
end

% Consider input data in absolute value
val = abs(val);
% If no modality (ex: surface mask, mri values...)
if isempty(DataType)
    DataType = 'none';
end
% Units depends on the data modality
switch lower(DataType)
    case {'meg', '$meg', 'meg grad', 'meg mag', '$meg grad', '$meg mag', 'meg grad2', 'meg grad3', 'meg gradnorm'}
        % MEG data in fT
        if (val < 1e-8)
            valFactor = 1e15;
            valUnits  = 'fT';
        % MEG data without units (zscore, stat...)
        else
            valFactor = 1;
            valUnits  = 'No units';
        end
        
    case {'eeg', '$eeg', 'ecog', '$ecog', 'seeg', '$seeg', 'eog', '$eog', 'ecg', '$ecg', 'emg', '$emg'}
        % EEG data in Volts, displayed in microVolts
        if (val < 0.01)
            valFactor = 1e6;
            valUnits = '\muV';
        % EEG data in Volts, displayed in milliVolts
        elseif (val < 1)
            valFactor = 1e3;
            valUnits = 'mV';
        % EEG data without units (zscore, stat...)
        else
            valFactor = 1;
            valUnits = 'No units';
        end
        
    case {'nirs', '$nirs'}
        % Concentrations
        if (val < 1)
            valFactor = 1e3;
            valUnits = 'mmol/l';
        % Wavelengths
        else
            valFactor = 1;
            valUnits = '\DeltaOD';
        end
        
    case {'results', 'sources', 'source'}
        % Results in Amper.meter (display in picoAmper.meter)
        if (val < 1e-4)
            valFactor = 1e12;
            valUnits  = 'pA.m';
        % Results without units (zscore, stat...)
        else
            valFactor = 1;
            valUnits  = 'No units';
        end
        
    case 'sloreta'
        if (val < 1e-4)
            [valFactor, valUnits] = GetExponent(val);
        else
            valFactor = 1;
            valUnits  = 'No units';
        end
        
    case 'stat'
        if (val < 1e-13)
            [valFactor, valUnits] = GetExponent(val);
        elseif (val < 1e-8)
            valFactor = 1e12;
            valUnits  = 'pA.m';
        elseif (val < 1e-3)
            [valFactor, valUnits] = GetExponent(val);
        else
            valFactor = 1;
            valUnits  = 'No units';
        end
        
    case 'connect'
        valFactor = 1;
        valUnits  = 'score';
        
    case 'timefreq'
        [valFactor, valUnits] = GetExponent(val);
        
    case 'hlu'
        valFactor = 1e3;
        valUnits  = 'mm';
        
    otherwise
        if isempty(val) || ((val < 1000) && (val > 0.1))
            valFactor = 1;
            valUnits  = 'No units';
        else
            [valFactor, valUnits] = GetExponent(val);
        end
end
% Scale input value
valScaled = val .* valFactor;

end

%% ===== GET EXPONENT =====
function [valFactor, valUnits] = GetExponent(val)
    if (val == 0)
        valFactor = 1;
        valUnits  = 'No units';
    else
        %exponent = round(log(val)/log(10) / 3) * 3;
        exponent = round(log(val)/log(10)) - 1;
        % Do not allow 10^-1 and 10^-2
        if (exponent == -1) || (exponent == -2)
            valFactor = 1;
            valUnits  = 'No units';
        else
            valFactor = 10 ^ -exponent;
            valUnits  = sprintf('10^{%d}', exponent);
        end
    end
end

