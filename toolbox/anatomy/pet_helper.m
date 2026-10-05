function varargout = pet_helper(varargin)
% PET_HELPER: Helper functions for PET volumes
% 
% USAGE: 
%    - PET = pet_helper('ReadMetadata', PetFile, sMri) :
%        Curated PET metadata (sMri.PET) from the BIDS JSON sidecar (*_pet.json),
%        with a NIfTI header fallback

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
% Authors: Diellor Basha, 2026

eval(macro_method);
end


%% ===== READ PET METADATA =====
function PET = ReadMetadata(PetFile, sMri)
% Build the curated PET metadata struct (sMri.PET) for a PET volume.
%
% Unlike a structural MRI, a PET volume is uninterpretable without its tracer,
% frame/injection timing and scanner/recon context. This function captures that
% metadata into a single inspectable struct that every downstream PET step
% (temporal windowing, SUVR, surface projection, PVC) reads from. The primary
% source is the BIDS JSON sidecar next to PetFile (*_pet.json); if it is absent,
% a partial struct is derived from the NIfTI header / loaded cube (sMri).
%
% This is a pure read/parse function: no database side effects.
%
% USAGE:  PET = pet_helper('ReadMetadata', PetFile, sMri)
%
% INPUTS:
%   PetFile : path to the PET volume being imported (e.g. *_pet.nii.gz). Its BIDS
%             JSON sidecar (*_pet.json) is looked up alongside it.
%   sMri    : (optional) loaded Brainstorm MRI struct. sMri.Cube is used for the
%             frame count and sMri.Header for the NIfTI-header fallback.
%
% OUTPUT:
%   PET : struct with fields .Source .Tracer .Injection .Frames .Decay .Scanner .Json
%         .Source         'bids-json' | 'nifti-header' | 'none'
%         .Tracer         .Name .Radionuclide .Units
%         .Injection      .InjectedRadioactivity .InjectedRadioactivityUnits .Mode
%                         .TimeZero .InjectionStart .ScanStart
%         .Frames         .TimesStart [1xN] .Duration [1xN] .N
%                         .MidTimes [1xN]          (derived)
%                         .CoverageMinPI [t0 t1]   (derived, minutes post-injection)
%         .Decay          .ImageDecayCorrected .ImageDecayCorrectionTime
%         .Scanner        .Manufacturer .Model .ReconMethod .ReconFilterType
%                         .ReconFilterSize .AttenuationCorrection
%         .Json           raw decoded JSON struct (verbatim); [] if header-only
%
% SEE ALSO: import_mri, ScannerFwhm

    if (nargin < 2)
        sMri = [];
    end

    PET = local_empty_pet();

    % ---- primary source: BIDS JSON sidecar ----
    jsonFile = local_find_sidecar(PetFile);
    if ~isempty(jsonFile)
        try
            J = bst_jsondecode(jsonFile);
        catch
            J = [];
        end
        if ~isempty(J)
            PET = local_from_json(PET, J);
            PET.Source = 'bids-json';
        end
    end

    % ---- fallback: NIfTI header / loaded cube ----
    if strcmp(PET.Source, 'none')
        PET = local_from_header(PET, sMri);
    end

    % ---- derived frame fields ----
    PET = local_derive_frames(PET);
end


%% ===== empty schema =====
function PET = local_empty_pet()
    PET = struct();
    PET.Source    = 'none';
    PET.Tracer    = struct('Name','', 'Radionuclide','', 'Units','');
    PET.Injection = struct('InjectedRadioactivity',[], 'InjectedRadioactivityUnits','', ...
                           'Mode','', 'TimeZero','', 'InjectionStart',[], 'ScanStart',[]);
    PET.Frames    = struct('TimesStart',[], 'Duration',[], 'N',0, 'MidTimes',[], 'CoverageMinPI',[]);
    PET.Decay     = struct('ImageDecayCorrected',[], 'ImageDecayCorrectionTime',[]);
    PET.Scanner   = struct('Manufacturer','', 'Model','', 'ReconMethod','', ...
                           'ReconFilterType','', 'ReconFilterSize',[], 'AttenuationCorrection','');
    PET.Json      = [];
end


%% ===== locate the BIDS JSON sidecar =====
function jsonFile = local_find_sidecar(PetFile)
    jsonFile = '';
    if isempty(PetFile) || iscell(PetFile)
        return;
    end
    [fPath, fBase, fExt] = bst_fileparts(PetFile);
    if strcmpi(fExt, '.gz')          % *.nii.gz -> strip the .nii too
        [~, fBase] = bst_fileparts(fBase);
    end
    if strncmp(fBase, '._', 2)       % macOS AppleDouble companion
        return;
    end
    cand = bst_fullfile(fPath, [fBase '.json']);
    if file_exist(cand)
        jsonFile = cand;
    end
end


%% ===== map BIDS JSON -> curated schema =====
function PET = local_from_json(PET, J)
    PET.Json = J;
    PET.Tracer.Name         = local_get(J, 'TracerName', '');
    PET.Tracer.Radionuclide = local_get(J, 'TracerRadionuclide', '');
    PET.Tracer.Units        = local_get(J, 'Units', '');

    PET.Injection.InjectedRadioactivity      = local_get(J, 'InjectedRadioactivity', []);
    PET.Injection.InjectedRadioactivityUnits = local_get(J, 'InjectedRadioactivityUnits', '');
    PET.Injection.Mode           = local_get(J, 'ModeOfAdministration', '');
    PET.Injection.TimeZero       = local_get(J, 'TimeZero', '');
    PET.Injection.InjectionStart = local_get(J, 'InjectionStart', []);
    PET.Injection.ScanStart      = local_get(J, 'ScanStart', []);

    PET.Frames.TimesStart = local_row(local_get(J, 'FrameTimesStart', []));
    PET.Frames.Duration   = local_row(local_get(J, 'FrameDuration', []));

    PET.Decay.ImageDecayCorrected      = local_get(J, 'ImageDecayCorrected', []);
    PET.Decay.ImageDecayCorrectionTime = local_get(J, 'ImageDecayCorrectionTime', []);

    PET.Scanner.Manufacturer          = local_get(J, 'Manufacturer', '');
    PET.Scanner.Model                 = local_get(J, 'ManufacturersModelName', '');
    PET.Scanner.ReconMethod           = local_get(J, 'ReconMethodName', '');
    PET.Scanner.ReconFilterType       = local_get(J, 'ReconFilterType', '');
    PET.Scanner.ReconFilterSize       = local_get(J, 'ReconFilterSize', []);
    PET.Scanner.AttenuationCorrection = local_get(J, 'AttenuationCorrection', '');
end


%% ===== NIfTI-header / cube fallback =====
function PET = local_from_header(PET, sMri)
    if isempty(sMri)
        return;   % Source stays 'none'
    end
    % Frame count from the loaded cube (most reliable indicator of N frames)
    if isfield(sMri, 'Cube') && ~isempty(sMri.Cube)
        PET.Frames.N = size(sMri.Cube, 4);
    end
    % Units, if the header carries them
    if isfield(sMri, 'Header') && ~isempty(sMri.Header) && isfield(sMri.Header, 'nifti') ...
            && isfield(sMri.Header.nifti, 'intent_name') && ~isempty(sMri.Header.nifti.intent_name)
        PET.Tracer.Units = sMri.Header.nifti.intent_name;
    end
    PET.Source = 'nifti-header';
end


%% ===== derived frame fields =====
function PET = local_derive_frames(PET)
    ts = PET.Frames.TimesStart;
    du = PET.Frames.Duration;
    if isempty(ts)
        return;
    end
    PET.Frames.N = numel(ts);
    if ~isempty(du) && (numel(du) == numel(ts))
        PET.Frames.MidTimes = ts + du / 2;
    end
    inj = PET.Injection.InjectionStart;
    if ~isempty(inj) && ~isempty(du) && (numel(du) == numel(ts))
        t0 = (min(ts)        - inj) / 60;    % minutes post-injection
        t1 = (max(ts + du)   - inj) / 60;
        PET.Frames.CoverageMinPI = [t0, t1];
    end
end


%% ===== getters =====
function v = local_get(J, name, def)
% Field value with default; BIDS 'n/a' sentinels map to the default.
    if isfield(J, name) && ~isempty(J.(name))
        v = J.(name);
        if ischar(v) && strcmpi(strtrim(v), 'n/a')
            v = def;
        end
    else
        v = def;
    end
end

function v = local_row(x)
% Coerce a JSON numeric array (column vector from jsondecode, or cell from the
% Brainstorm fallback decoder) into a double row vector.
    if iscell(x)
        x = cell2mat(x);
    end
    if isempty(x)
        v = [];
    else
        v = double(x(:)');
    end
end
