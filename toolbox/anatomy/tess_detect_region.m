function sScouts = tess_detect_region(sScouts)
% TESS_DETECT_REGION: Detect the scout region based on its name

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013-2019

% Loop on all the scouts
for i = 1:length(sScouts)
    % Remove L and R tags
    if (length(sScouts(i).Label) > 3) && ismember(sScouts(i).Label(end-1:end), {' L', ' R'})
        sScouts(i).Label = sScouts(i).Label(1:end-2);
    end
    % Detect region based on the scout name
    % USCBrain labels have subdivisions after ' - ', so remove part after
    ind = strfind(sScouts(i).Label, ' - ');
    if isempty(ind)
        scout_name = sScouts(i).Label;
    else
        scout_name = sScouts(i).Label(1:ind-1);
    end
    switch lower(scout_name)
    % ==== FREESURFER: DESTRIEUX ====
        % Pre-frontal / Orbital
        case 's_orbital-h_shaped',          region = 'PF';
        case 'g_orbital',                   region = 'PF';
        case 's_orbital_med-olfact',        region = 'PF';
        case 's_suborbital',                region = 'PF';
        case 'g_and_s_frontomargin',        region = 'PF';
        case 'g_rectus',                    region = 'PF';
        case 'g_and_s_transv_frontopol',    region = 'PF';
        case 's_orbital_lateral',           region = 'PF';
        % Frontal
        case 's_front_sup',                 region = 'F';
        case 's_front_middle',              region = 'F';
        case 'g_front_sup',                 region = 'F';
        case 'g_front_middle',              region = 'F';
        case 's_front_inf',                 region = 'F';
        case 'g_front_inf-opercular',       region = 'F';
        case 'g_front_inf-orbital',         region = 'F';        
        case 'g_front_inf-triangul',        region = 'F';
        case 'lat_fis-ant-vertical',        region = 'F';
        case 'lat_fis-ant-horizont',        region = 'F';
        % Central
        case 'g_precentral',                region = 'C';
        case 's_central',                   region = 'C';
        case 'g_postcentral',               region = 'C';
        case 's_postcentral',               region = 'C';
        case 'g_and_s_paracentral',         region = 'C';
        case 'g_and_s_subcentral',          region = 'C';
        case 's_precentral-inf-part',       region = 'C';
        case 's_precentral-sup-part',       region = 'C';
        case 's_cingul-marginalis',         region = 'C';
        % Parietal
        case 'g_parietal_sup',              region = 'P';
        case 's_subparietal',               region = 'P';
        case 'g_pariet_inf-supramar',       region = 'P';
        case 'g_pariet_inf-angular',        region = 'P';
        case 's_interm_prim-jensen',        region = 'P';
        case 's_intrapariet_and_p_trans',   region = 'P';
        case 's_parieto_occipital',         region = 'P';
        case 'g_precuneus',                 region = 'P';
        % Temporal
        case 'pole_temporal',               region = 'T';
        case 's_temporal_sup',              region = 'T';
        case 'g_temporal_middle',           region = 'T';
        case 's_temporal_transverse',       region = 'T';
        case 'g_temporal_inf',              region = 'T';
        case 's_temporal_inf',              region = 'T';
        case 'g_temp_sup-lateral',          region = 'T';
        case 'g_temp_sup-g_t_transv',       region = 'T';
        case 'g_temp_sup-plan_tempo',       region = 'T';
        case 'g_temp_sup-plan_polar',       region = 'T';
        case 'g_oc-temp_lat-fusifor',       region = 'T';
        case 'g_oc-temp_med-parahip',       region = 'T';
        case 's_oc-temp_lat',               region = 'T';
        case 'lat_fis-post',                region = 'T';
        case 's_collat_transv_ant',         region = 'T';
        case 'g_ins_lg_and_s_cent_ins',     region = 'T';
        case 's_circular_insula_inf',       region = 'T';
        case 's_oc-temp_med_and_lingual',   region = 'T';
        case 'g_insular_short',             region = 'T';
        case 's_circular_insula_sup',       region = 'T';
        case 's_circular_insula_ant',       region = 'T';
        % Occipital    
        case 'pole_occipital',              region = 'O';
        case 'g_occipital_sup',             region = 'O';
        case 's_occipital_ant',             region = 'O';
        case 'g_occipital_middle',          region = 'O';
        case 'g_and_s_occipital_inf',       region = 'O';
        case 's_oc_middle_and_lunatus',     region = 'O';
        case 's_oc_sup_and_transversal',    region = 'O';    
        case 'g_oc-temp_med-lingual',       region = 'O';
        case 'g_cuneus',                    region = 'O';
        case 's_calcarine',                 region = 'O';
        case 's_collat_transv_post',        region = 'O';
        % Limbic
        case 'g_subcallosal',               region = 'L';
        case 's_pericallosal',              region = 'L';
        case 'g_cingul-post-ventral',       region = 'L';
        case 'g_and_s_cingul-ant',          region = 'L';
        case 'g_and_s_cingul-mid-ant',      region = 'L';
        case 'g_and_s_cingul-mid-post',     region = 'L';
        case 'g_cingul-post-dorsal',        region = 'L';

    % ==== FREESURFER: DESIKAN-KILLIANY ====
        % Pre-frontal / Orbital
        case 'frontalpole',                 region = 'PF';
        case 'lateralorbitofrontal',        region = 'PF';
        case 'medialorbitofrontal',         region = 'PF';
        case 'parsorbitalis',               region = 'PF';
        case 'laterola',                    region = 'PF';
        case 'parsorib',                    region = 'PF';
        case 'pastrnauglaros',              region = 'PF';
        case 'triangular',                  region = 'PF';
        % Frontal
        case 'parsopecu',                   region = 'F';
        case 'parsopecui',                  region = 'F';
        case 'superiorfrontal',             region = 'F';
        case 'parstriangularis',            region = 'F';
        case 'parsopercularis',             region = 'F';
        case 'caudalmiddlefrontal',         region = 'F';
        case 'rostralmiddlefrontal',        region = 'F';
        % Central
        case 'precentral',                  region = 'C';
        case 'postcentral',                 region = 'C';
        case 'paracentral',                 region = 'C';
        % Parietal
        case 'supramarginal',               region = 'P';
        case 'precentaleright',             region = 'P';
        case 'superiorparietal',            region = 'P';
        case 'inferiorparietal',            region = 'P';
        case 'precuneus',                   region = 'P';
        % Temporal
        case 'entorhinal',                  region = 'T';
        case 'fusiform',                    region = 'T';
        case 'middletemporal',              region = 'T';
        case 'parahippocampal',             region = 'T';
        case 'superiortemporal',            region = 'T';
        case 'temporalpole',                region = 'T';
        case 'transversetemporal',          region = 'T';
        case 'inforetempor',                region = 'T';
        case 'inferiortemporal',            region = 'T';
        case 'bankssts',                    region = 'T';
        case 'insula',                      region = 'T';
        % Occipital
        case 'cuneus',                      region = 'O';
        case 'pericalcarine',               region = 'O';
        case 'lingual',                     region = 'O';
        case 'lateraloccipital',            region = 'O';
        % Limbic
        case 'caudalanteriorcingulate',     region = 'L';
        case 'isthmuscingulate',            region = 'L';
        case 'posteriorcingulate',          region = 'L';
        case 'rostralanteriorcingulate',    region = 'L';
        case 'rosrlantcingu',               region = 'L';

    % ==== FREESURFER: BRODMAN ====
        % Frontal
        case 'ba44',                        region = 'F';
        case 'ba45',                        region = 'F';
        case 'ba6',                         region = 'F';
        case 'ba4a',                        region = 'F';
        case 'ba4p',                        region = 'F';
        % Central
        case 'ba1',                         region = 'C';
        case 'ba2',                         region = 'C';
        case 'ba3a',                        region = 'C';
        case 'ba3b',                        region = 'C';
        % Occipital
        case 'mt',                          region = 'O';
        case 'v1',                          region = 'O';
        case 'v2',                          region = 'O';
        % Temporal
        case 'perirhinal',                  region = 'T';

    % ==== FREESURFER: PALS BRODMAN ====
        % Prefrontal
        case 'brodmann.10',     region = 'PF';
        case 'brodmann.11',     region = 'PF';
        % Frontal
        case 'brodmann.6',      region = 'F';
        case 'brodmann.8',      region = 'F';
        case 'brodmann.9',      region = 'F';
        case 'brodmann.32',     region = 'F';
        case 'brodmann.44',     region = 'F';
        case 'brodmann.45',     region = 'F';
        case 'brodmann.46',     region = 'F';
        case 'brodmann.47',     region = 'F';
        % Central
        case 'brodmann.1',      region = 'C';
        case 'brodmann.2',      region = 'C';
        case 'brodmann.3',      region = 'C';
        case 'brodmann.4',      region = 'C';
        case 'brodmann.43',     region = 'C';
        % Parietal
        case 'brodmann.5',      region = 'P';
        case 'brodmann.7',      region = 'P';
        case 'brodmann.31',     region = 'P';
        case 'brodmann.40',     region = 'P';
        case 'brodmann.41',     region = 'P';
        % Occipital
        case 'brodmann.17',     region = 'O';
        case 'brodmann.18',     region = 'O';  
        case 'brodmann.19',     region = 'O';
        case 'brodmann.39',     region = 'O';
        % Temporal
        case 'brodmann.20',     region = 'T';
        case 'brodmann.21',     region = 'T';
        case 'brodmann.22',     region = 'T';
        case 'brodmann.28',     region = 'T';
        case 'brodmann.36',     region = 'T';
        case 'brodmann.37',     region = 'T';
        case 'brodmann.38',     region = 'T';
        case 'brodmann.42',     region = 'T';
        % Limbic
        case 'brodmann.23',     region = 'L';
        case 'brodmann.24',     region = 'L';
        case 'brodmann.25',     region = 'L';
        case 'brodmann.26',     region = 'L';
        case 'brodmann.27',     region = 'L';
        case 'brodmann.29',     region = 'L';
        case 'brodmann.30',     region = 'L';
        case 'brodmann.35',     region = 'L';
            
    % ==== FREESURFER: PALS LOBES ====
        case 'lobe.frontal',    region = 'F';
        case 'lobe.limbic',     region = 'L';
        case 'lobe.occipital',  region = 'O';
        case 'lobe.parietal',   region = 'P';
        case 'lobe.temporal',   region = 'T';

    % ==== BRAINSUITE: SVREG ====
        % Prefrontal
        case 'anterior orbito-frontal gyrus',  region = 'PF';
        case 'lateral orbitofrontal gyrus',    region = 'PF';
        case 'middle orbito-frontal gyrus',    region = 'PF';
        case 'posterior orbito-frontal gyrus', region = 'PF';
        case 'transvers frontal gyrus',        region = 'PF';
        case 'transverse frontal gyrus',       region = 'PF';            
        case 'gyrus rectus',                   region = 'PF';
        case 'pars orbitalis',                 region = 'PF';
        % Frontal
        case 'superior frontal gyrus',         region = 'F';
        case 'middle frontal gyrus',           region = 'F';
        case 'pars triangularis',              region = 'F';
        case 'pars opercularis',               region = 'F';
        % Central
        case 'paracentral lobule',             region = 'C';
        case 'post-central gyrus',             region = 'C';
        case 'postcentral gyrus',              region = 'C';            
        case 'pre-central gyrus',              region = 'C';
        case 'precentral gyrus',               region = 'C';            
        % Parietal
        case 'pre-cuneus',                     region = 'P';
        case 'angular gyrus',                  region = 'P';
        case 'superior parietal gyrus',        region = 'P';
        case 'supramarginal gyrus',            region = 'P';
        % Temporal
        %case 'insula',                        region = 'T';
        case 'fusiforme gyrus',                region = 'T';
        case 'fusiform gyrus',                region = 'T';            
        case 'inferior temporal gyrus',        region = 'T';
        case 'middle temporal gyrus',          region = 'T';
        case 'transverse temporal gyrus',      region = 'T';
        case 'parahippocampal gyrus',          region = 'T';
        case 'superior temporal gyrus',        region = 'T';
        case 'temporal pole',                  region = 'T';
        % Occipital
        %case 'cuneus',                        region = 'O';
        case 'inferior occipital gyrus',       region = 'O';
        case 'middle occipital gyrus',         region = 'O';
        case 'superior occipital gyrus',       region = 'O';
        case 'lingual gyrus',                  region = 'O';
        % Limbic
        case 'cingulate gyrus',                region = 'L'; 
        case 'subcallosal area',               region = 'L'; 
        case 'subcallosal gyrus',              region = 'L'; 

    % ===== BRAINVISA MARSATLAS =====
        % Prefrontal
        case 'ofcvl',  region = 'PF';
        case 'ofcv',   region = 'PF';
        case 'ofcvm',  region = 'PF';
        case 'pfcvm',  region = 'PF';
        % Frontal
        case 'pmrv',   region = 'F';
        case 'pmdl',   region = 'F';
        case 'pmdm',   region = 'F';
        case 'pfcdl',  region = 'F';
        case 'pfcdm',  region = 'F';
        case 'pfrvl',  region = 'F';
        case 'pfrdli', region = 'F';
        case 'pfrdls', region = 'F';
        case 'pfrd',   region = 'F';
        case 'pfrm',   region = 'F';
        % Central
        case 'mv',     region = 'C';
        case 'mdl',    region = 'C';
        case 'mdm',    region = 'C';
        case 'sv',     region = 'C';
        case 'sdl',    region = 'C';
        case 'sdm',    region = 'C';
        % Parietal
        case 'ipcv',   region = 'P';
        case 'ipcd',   region = 'P';
        case 'spc',    region = 'P';
        case 'spcm',   region = 'P';
        case 'pcm',    region = 'P';
        % Temporal
        case 'itcm',   region = 'T';
        case 'itcr',   region = 'T';
        case 'mtcc',   region = 'T';
        case 'stcc',   region = 'T';
        case 'stcr',   region = 'T';
        case 'mtcr',   region = 'T';
        % Occipital
        case 'vccm',   region = 'O';
        case 'vcl',    region = 'O';
        case 'vcs',    region = 'O';
        case 'cu',     region = 'O';
        case 'vcrm',   region = 'O';
        % Limbic
        case 'icc',    region = 'L';
        case 'pcc',    region = 'L';
        case 'mcc',    region = 'L';
        case 'acc',    region = 'L';

        % DEFAULT: Unknown
        otherwise
            if ~isempty(strfind(sScouts(i).Label, 'OngurEtAl'))
                region = 'PF';
            elseif~isempty(strfind(sScouts(i).Label, 'Visuotopic.'))
                region = 'O';
            else
                region = 'U';
            end
    end
    % Set scout region
    if ~isempty(sScouts(i).Region)
        sScouts(i).Region = [sScouts(i).Region(1), region];
    else
        sScouts(i).Region = ['U', region];
    end
end




