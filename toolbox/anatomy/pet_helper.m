function varargout = pet_helper(varargin)
% PET_HELPER: Helper functions for PET volumes
% 
% USAGE: 
%    - PET = pet_helper('ReadMetadata', PetFile, sMri) :
%        Curated PET metadata (sMri.PET) from the BIDS JSON sidecar (*_pet.json),
%        with a NIfTI header fallback
%    - [fwhm, src] = pet_helper('ScannerFwhm', PET)
%    - [fwhm, src] = pet_helper('ScannerFwhm', PET, defaultFwhm) :
%        Scanner PSF FWHM (mm) from the scanner model and reconstruction filter
%        in the PET metadata (fallback: defaultFwhm, 6 mm)
%    - [fwhm, src] = pet_helper('PsfFwhm', PET)
%    - [fwhm, src] = pet_helper('PsfFwhm', PET, fwhmScanner) :
%        Effective PSF FWHM (mm): scanner resolution (fwhmScanner, or stored at import)
%        and the smoothing recorded in PET.SmoothFwhm, added in quadrature

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


%% ===== SCANNER RESOLUTION =====
function [fwhm, src] = ScannerFwhm(PET, defaultFwhm)
% Estimate effective PET image resolution (PSF FWHM, mm) from metadata.
%
% BIDS PET (and the NIfTI header) carry NO explicit image-resolution / PSF field,
% so the effective in-brain FWHM is INFERRED from the scanner MODEL (a curated
% lookup of published effective resolutions) combined with any applied
% reconstruction Gaussian post-filter (ReconFilterType / ReconFilterSize). When the
% scanner cannot be identified from the metadata, a generic fallback (~6 mm, typical
% clinical PET) is returned so partial-volume correction still has a sane default.
%
% The lookup values are approximate published effective in-brain resolutions and are
% meant as sensible defaults; pass an explicit FWHM to pet_pvc to override.
%
% USAGE:  [fwhm, src] = pet_helper('ScannerFwhm', PET)
%         [fwhm, src] = pet_helper('ScannerFwhm', PET, defaultFwhm)
%
% INPUT:
%   PET         : sMri.PET metadata struct (see ReadMetadata). May be [].
%   defaultFwhm : fallback FWHM in mm when the scanner is unknown (default 6).
%
% OUTPUT:
%   fwhm : estimated isotropic PSF FWHM in mm.
%   src  : human-readable provenance string (for logging / GUI).
%
% SEE ALSO: ReadMetadata, pet_pvc

    if (nargin < 2) || isempty(defaultFwhm), defaultFwhm = 6; end
    fwhm = defaultFwhm;
    src  = sprintf('fallback %.1f mm (scanner not identified)', defaultFwhm);

    if isempty(PET) || ~isstruct(PET) || ~isfield(PET, 'Scanner')
        return;
    end
    model = local_str(local_getf(PET.Scanner, 'Model'));
    manuf = local_str(local_getf(PET.Scanner, 'Manufacturer'));
    hay   = lower([model ' ' manuf]);

    % Curated scanner -> intrinsic effective in-brain FWHM (mm). Order specific->general;
    % first matching key wins. Values are approximate published figures.
    tbl = { ...
        {'hrrt','high-resolution research','high resolution research'}, 2.5; ...
        {'vision quadra','biograph vision','vision'},                   3.6; ...
        {'biograph mmr','mmr'},                                         4.3; ...
        {'biograph mct','mct'},                                         4.4; ...
        {'discovery mi','dmi'},                                         4.2; ...
        {'discovery'},                                                  5.0; ...
        {'signa'},                                                      4.4; ...
        {'vereos'},                                                     4.0; ...
        {'biograph'},                                                   4.4; ...
        {'ecat'},                                                       6.0  ...
    };
    intr = []; label = '';
    for i = 1:size(tbl,1)
        keys = tbl{i,1};
        if any(cellfun(@(k) ~isempty(strfind(hay, k)), keys)) %#ok<STREMP>
            intr = tbl{i,2}; label = upper(keys{1}); break;
        end
    end
    if isempty(intr)
        return;   % keep the fallback
    end

    fwhm = intr;
    src  = sprintf('%.1f mm (%s, model lookup)', intr, label);

    % Combine with an applied reconstruction Gaussian post-filter, if present.
    ft = lower(local_str(local_getf(PET.Scanner, 'ReconFilterType')));
    fs = local_getf(PET.Scanner, 'ReconFilterSize');
    if isnumeric(fs) && isscalar(fs) && (fs > 0) && (~isempty(strfind(ft, 'gauss'))) %#ok<STREMP>
        fwhm = sqrt(intr^2 + double(fs)^2);
        src  = sprintf('%.1f mm (%s %.1fmm + %.1fmm recon Gaussian)', fwhm, label, intr, fs);
    end
end


%% ===== helpers =====
function v = local_getf(s, f)
    if isstruct(s) && isfield(s, f), v = s.(f); else, v = []; end
end

function s = local_str(v)
    if ischar(v), s = v; elseif isempty(v), s = ''; else, s = num2str(v); end
end


%% ===== EFFECTIVE PSF =====
function [fwhm, src] = PsfFwhm(PET, fwhmScanner)
% Effective PSF FWHM (mm) of a PET volume: scanner resolution + recorded smoothing.
%
% The scanner resolution is resolved once at import (ReadMetadata + ScannerFwhm) and
% stored as PET.PsfFwhm, so that it survives realignment, co-registration and reslicing. Any
% Gaussian smoothing applied afterwards (import "Apply smoothing", mri_realign FWHM, pet_process
% SmoothFWHM) is recorded in PET.SmoothFwhm and added in quadrature:
%
%     FWHM_eff = sqrt( FWHM_scanner^2 + sum_k FWHM_smooth(k)^2 )
%
% USAGE:  [fwhm, src] = pet_helper('PsfFwhm', PET)
%         [fwhm, src] = pet_helper('PsfFwhm', PET, fwhmScanner)
%
% INPUTS:
%   PET         : sMri.PET metadata struct (may be [] for volumes without metadata).
%   fwhmScanner : (optional) scanner FWHM in mm given by the user; overrides PET.PsfFwhm.
%                 The recorded smoothing is still added.
%
% OUTPUTS:
%   fwhm : effective isotropic PSF FWHM in mm.
%   src  : human-readable provenance string (for the history and the command window).
%
% SEE ALSO: ScannerFwhm, ReadMetadata, pet_pvc

    if (nargin < 2), fwhmScanner = []; end
    % Scanner resolution: user value > value stored at import > lookup now (older files)
    if ~isempty(fwhmScanner)
        fwhm0 = double(fwhmScanner(1));
        src   = sprintf('%.1f mm (user)', fwhm0);
    elseif isstruct(PET) && isfield(PET, 'PsfFwhm') && ~isempty(PET.PsfFwhm)
        fwhm0 = double(PET.PsfFwhm(1));
        if isfield(PET, 'PsfSource') && ~isempty(PET.PsfSource)
            src = PET.PsfSource;
        else
            src = sprintf('%.1f mm (stored at import)', fwhm0);
        end
    else
        [fwhm0, src] = ScannerFwhm(PET);
    end
    % Recorded smoothing, added in quadrature
    fwhm = fwhm0;
    if isstruct(PET) && isfield(PET, 'SmoothFwhm') && ~isempty(PET.SmoothFwhm)
        sm = double(PET.SmoothFwhm(:));
        sm = sm(isfinite(sm) & (sm > 0));
        if ~isempty(sm)
            fwhm = sqrt(fwhm0^2 + sum(sm.^2));
            src  = sprintf('%.2f mm = sqrt(%.1f^2 + smoothing %s^2) [scanner: %s]', ...
                           fwhm, fwhm0, mat2str(sm'), src);
        end
    end
end
