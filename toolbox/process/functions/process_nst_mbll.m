function varargout = process_nst_mbll( varargin )

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
% Authors: Thomas Vincent, Francois Tadel, 2015-2016

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Compute concentrations (HbO,HbR,HbT)';
    sProcess.FileTag     = ' | Hb';
    sProcess.Category    = 'File';
    sProcess.SubGroup    = 'NIRS';
    sProcess.Index       = 1010; %0: not shown, >0: defines place in the list of processes
    %sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/NIRSDataPreprocessing#MBLL';
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/TutUserProcess';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'};
    % Definition of the outputs of this process
    sProcess.OutputTypes = {'data', 'data'}; %TODO: 'raw' -> 'raw' or 'raw' -> 'data'?
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    sProcess.options.option_age.Comment = 'Age';
    sProcess.options.option_age.Type    = 'value';
    sProcess.options.option_age.Value   = {25, 'years', 2};
    sProcess.options.option_baseline_method.Comment = 'Baseline method';
    sProcess.options.option_baseline_method.Type    = 'combobox';
    sProcess.options.option_baseline_method.Value   = {1, {'mean', 'median'}};    % {Default index, {list of entries}}

    sProcess.options.option_do_plp_corr.Comment = 'Light path length correction';
    sProcess.options.option_do_plp_corr.Type    = 'checkbox';
    sProcess.options.option_do_plp_corr.Value   = 1;
end

%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end

%% ===== RUN =====
function OutputFile = Run(sProcess, sInput) %#ok<DEFNU>
    % Get option values   
    age             = sProcess.options.option_age.Value{1};
    blm_idx         = sProcess.options.option_baseline_method.Value{1};
    baseline_method = sProcess.options.option_baseline_method.Value{2}{blm_idx};
    do_plp_corr     = sProcess.options.option_do_plp_corr.Value;
    
    % ===== LOAD INPUTS =====
    % Load channel file
    ChanneMat = in_bst_channel(sInput.ChannelFile);
    % Load imported data structure
    if strcmp(sInput.FileType, 'data')     
        sDataIn = in_bst_data(sInput.FileName);
        events = sDataIn.Events;
    % Load continuous data file       
    elseif strcmp(sInput.FileType, 'raw')
        sDataIn = in_bst(sInput.FileName, [], 1, 1, 'no');
        sDataRaw = in_bst_data(sInput.FileName, 'F');
        sFileIn = sDataRaw.F;
        events = sFileIn.events;
    end
    
    % ===== COMPUTE CONCENTRATIONS =====
    % Check for bad channels that haven't been removed
    if any(any(sDataIn.F(sDataIn.ChannelFlag~=-1, :) < 0))
        msg = 'Good channels contains negative values. Consider running NISTORM -> Set bad channels';
        bst_error(msg, '[Hb] quantification', 0);
        return;
    end
    % Remove bad channels: they won't enter MBLL computation so no need to keep them 
    [good_nirs, good_channel_def] = filter_bad_channels(sDataIn.F', ChanneMat, sDataIn.ChannelFlag);
    % Separate NIRS channels from others (NIRS_AUX etc.)                                                
    [fnirs, fchannel_def, nirs_other, channel_def_other] = filter_data_by_channel_type(good_nirs, good_channel_def, 'NIRS');
    % Apply MBLL
    [nirs_hb, channels_hb] = Compute(fnirs, fchannel_def, age, baseline_method, do_plp_corr); 
    % Re-add other channels that were not changed during MBLL
    [final_nirs, ChannelMat] = concatenate_data(nirs_hb, channels_hb, nirs_other, channel_def_other);
    

    % ===== SAVE OUTPUT DATA =====
    % Create new condition because channel definition is different from original one
    iOutputStudy = db_add_condition(sInput.SubjectName, [sInput.Condition, '_Hb']);
    sOutputStudy = bst_get('Study', iOutputStudy);
    % Save channel definition
    [tmp, iChannelStudy] = bst_get('ChannelForStudy', iOutputStudy);
    db_set_channel(iChannelStudy, ChannelMat, 0, 0);
    % Get input filename
    [fPath, fBase, fExt] = bst_fileparts(sInput.FileName);
    
    % Output data structure
    sDataOut = db_template('datamat');
    sDataOut.F            = final_nirs';
    sDataOut.Comment      = 'Hb';
    sDataOut.ChannelFlag  = ones(size(final_nirs, 2), 1);
    sDataOut.Time         = sDataIn.Time;
    sDataOut.DataType     = 'recordings'; 
    sDataOut.nAvg         = 1;
    sDataOut.Leff         = 1;
    sDataOut.Events       = events;
    sDataOut.Device       = sDataIn.Device;
    sDataOut.History      = sDataIn.History;
    % Add history field
    sDataOut = bst_history('add', sDataOut, 'process', sProcess.Comment);
    
    % Continuous data file: Save .bst file
    if strcmp(sInput.FileType, 'raw')
        % Prepare sFile structure
        ExportFile = bst_fullfile(bst_fileparts(file_fullpath(sOutputStudy.FileName)), [strrep(fBase, 'data_0raw_', ''), '_Hb.bst']);
        % Export binary file
        [ExportFile, sFileOut] = export_data(sDataOut, ChannelMat, ExportFile, 'BST-BIN');
        % Update data structure
        sFileOut.comment  = '';
        sDataOut.F        = sFileOut;
        sDataOut.DataType = 'raw';
    end
    
    % Output data file
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sOutputStudy.FileName), [fBase, '_Hb.mat']);
    % Save file on hard drive
    bst_save(OutputFile, sDataOut, 'v6');
    % Add file to database
    db_add_data(iOutputStudy, OutputFile, sDataOut);
end





%% =====================================================================
%  ===== COMPUTATION FUNCTIONS =========================================
%  =====================================================================
function [fdata, fchannel_def] = filter_bad_channels(data, channel_def, channel_flags)
% Filter the given data based on bad channel flags
%
% Args:
%    - data: matrix of double, size: nb_samples x nb_channels
%      data time-series to filter
%    - channel_def: struct
%        Defintion of channels as given by brainstorm
%        Used field: Channel
%    - channel_flags: array of int, default: []
%        Channel flags. Channel with flag -1 are filtered
%        If [] is given, all channels are kept.
if nargin < 3 || isempty(channel_flags)
    channel_flags = ones(length(channel_def.Channel), 1);
end

kept_ichans = channel_flags' ~= -1;

fchannel_def = channel_def;
fchannel_def.Channel = channel_def.Channel(kept_ichans);
fdata = data(:, kept_ichans);
end


function [fdata, fchannel_def, data_other, channel_def_other] = ...
    filter_data_by_channel_type(data, channel_def, channel_types)

%    - channel_types: str or cell array of str
%        Channel types to keep.
%        If [] is given then all channels are kept.

if nargin < 3 || isempty(channel_types)
    channel_types = unique({channel_def.Channel.Type});
else
    if isstr(channel_types)
        channel_types = {channel_types};
    end
end

kept_ichans = ismember({channel_def.Channel.Type}, channel_types);
fchannel_def = channel_def;
fchannel_def.Channel = channel_def.Channel(kept_ichans);
fdata = data(:, kept_ichans);

other_ichans = ~kept_ichans;
channel_def_other = channel_def;
channel_def_other.Channel = channel_def.Channel(other_ichans);
data_other = data(:, other_ichans);
end

function [data_concat, channel_def_concat] = ...
    concatenate_data(data, channel_def, data_supp, channel_def_supp)

data_concat = [data data_supp];
channel_def_concat = channel_def;
channel_def_concat.Channel = [channel_def_concat.Channel channel_def_supp.Channel];
end


function [nirs_hb, channel_hb_def] = ...
    Compute(nirs_sig, channel_def, age, normalize_method, do_plp_corr)
%% Apply MBLL to compute [HbO] & [HbR] from given nirs OD data
% Args
%    - nirs_sig: matrix of double, size: nb_samples x nb_channels
%        Measured nirs signal (Optical density). Should not contain
%        negative values
%    - channel_def: struct
%        Defintion of channels as given by brainstorm
%        Used fields: Nirs.Wavelengths, Channel
%        ASSUME: channel coordinates are in meters
%    [- age ]: positive double, default is 25
%        Age of the subject, used for light path length correction
%    [- normalize_method]: str in {'mean','median'}, default: 'mean'
%        Method to compute delta optical density values: how to compute the
%        reference intensity against which to compute variations.
%    [- do_ppl_corr]: bool, default: 1
%        Flag to enable partial light path correction (account for light
%        scattering through head tissues)
% 
% Output: 
%   - nirs_hb: matrix of double, size: nb_samples x (nb_channels/nb_wavelengths)*2
%       HbO and HbO delta concentration time-series in mol.l^-1
%   - channel_hb_def: struct 
%       definition of new Hb-related channels. Relevant content:
%           Nirs.Hb = {'HbO', 'HbR', 'HbT'};
%           Channel(ichan1).Name = 'SXDXHbO'; % pair SXDX, HbO component
%           Channel(ichan1).Loc = [C C C]; % pair localization (imported from
%                                          % input channel_def)
%           Channel(ichan1).Group = 'HbO'; 
%           Channel(ichan2).Name = 'SXDXHbR'; % pair SXDX, HbR component
%           Channel(ichan2).Loc = [C C C]; % pair localization (imported from
%                                          % input channel_def, same as paired 
%                                          % channel ichan1)
%           Channel(ichan3).Group = 'HbR'; 
%           Channel(ichan3).Name = 'SXDXHbT'; % pair SXDX, HbT component
%           Channel(ichan3).Loc = [C C C]; % pair localization (imported from
%                                          % input channel_def, same as paired 
%                                          % channel ichan1)
%           Channel(ichan3).Group = 'HbT'; 
% TODO: check negative values
if nargin < 3
    age = 25;
end

if nargin < 4
    normalize_method = 'mean';
end

if nargin < 5
   do_plp_corr = 1; 
end

[nirs_psig, pair_names, pair_loc, pair_indexes] = group_paired_channels(nirs_sig, channel_def);
pair_distances = cpt_distances(channel_def.Channel, pair_indexes) * 100; %convert to cm

nb_pairs = length(pair_names);
nb_samples = size(nirs_sig, 1);
nirs_hb_p = zeros(nb_pairs, 3, nb_samples);
for ipair=1:size(nirs_psig, 1)
    hb_extinctions = get_hb_extinctions(channel_def.Nirs.Wavelengths); % cm^-1.l.mol^-1
    delta_od = normalize_nirs(squeeze(nirs_psig(ipair, :, :)), ...
                              normalize_method);
    if do_plp_corr
        %TODO: ppf can be computed only once before the loop over pairs
        delta_od_ppf_fixed = fix_ppf(delta_od, channel_def.Nirs.Wavelengths, age);
    else
        delta_od_ppf_fixed = delta_od;
    end
	nirs_hb_p(ipair, 1:2, :) = 1 ./ pair_distances(ipair) .* ...
                               pinv(hb_extinctions) * delta_od_ppf_fixed; %mol.l^-1
    nirs_hb_p(ipair, 3, :) = sum(nirs_hb_p(ipair, 1:2, :), 2);
end
[nirs_hb, channel_hb_def] = pack_hb_channels(nirs_hb_p, pair_names, pair_loc, channel_def);
end

function [nirs_hb, channel_hb_def] = pack_hb_channels(nirs, pair_names, pair_loc, channel_def_orig)
%% Reshape given nirs data to have size: time x nb_channels
%% Build new Hb-specific channel listing
%
% Args:
%    - nirs: array of double, size: nb_pairs x 3 x nb_samples
%        NIRS data to reshape (second axis corresponds to [HbO, HbR, HbT])
%    - pair_names: cell array of str, size; nb_pairs
%        Pair names (format: SXDY, where X and Y are the src and det indexes, resp.)
%    - pair_loc: matrix of double, size: (nb_pairs, 3)
%        Spatial coordinates of pairs. Loc(:,1) is source, Loc(:,2) is detector
%    - channel_def_orig: struct
%        Initial defintion of channels as given by brainstorm
%        Used to import field that remain the same after MBBL
%        -> only fields 'Nirs' and 'Channel' are redefined
%
% Outputs:
%   - nirs_hb: matrix of double, size: time x (nb_channels/nb_wavelengths)*2
%       HbO and HbO delta concentration time-series
%   - channel_hb_def: struct 
%       definition of new Hb-related channels. Relevant content:
%           Nirs.Hb = {'HbO', 'HbR', 'HbT'};
%           Channel(ichan1).Name = 'SXDXHbO'; % pair SXDX, HbO component
%           Channel(ichan1).Loc = [C C C]; % pair localization (imported from
%                                          % input channel_def)
%           Channel(ichan1).Group = 'HbO'; 
%           Channel(ichan2).Name = 'SXDXHbR'; % pair SXDX, HbO component
%           Channel(ichan2).Loc = [C C C]; % pair localization (imported from
%                                          % input channel_def, same as paired 
%                                          % channel ichan1)
%           Channel(ichan2).Group = 'HbR'; 
%           Channel(ichan3).Name = 'SXDXHbT'; % pair SXDX, HbT component
%           Channel(ichan3).Loc = [C C C]; % pair localization (imported from
%                                          % input channel_def, same as paired 
%                                          % channel ichan1)
%           Channel(ichan3).Group = 'HbT'; 

channel_hb_def = channel_def_orig;
ichan = 1;
hb_names = {'HbO', 'HbR', 'HbT'};
for ipair=1:size(nirs, 1)
    for ihb=1:length(hb_names)
        nirs_hb(:, ichan) = squeeze(nirs(ipair, ihb, :));
        Channel(ichan).Name = [pair_names{ipair} hb_names{ihb}];
        Channel(ichan).Loc = squeeze(pair_loc(ipair, :, :));
        Channel(ichan).Group = hb_names{ihb};
        Channel(ichan).Comment = [];
        Channel(ichan).Orient = [];
        Channel(ichan).Weight = 1;
        Channel(ichan).Type = 'NIRS';
        ichan = ichan + 1;
    end
end

channel_hb_def.Nirs = rmfield(channel_hb_def.Nirs, 'Wavelengths');

channel_hb_def.Nirs.Hb = hb_names;
channel_hb_def.Channel = Channel;
channel_hb_def.Comment = ['NIRS-BRS sensors (' num2str(length(Channel)) ')'];
end

function delta_od_fixed = fix_ppf(delta_od, wavelengths, age)
%% Fix given optival density measurements to correct for the differential light path 
%% length: account for light scattering within head tissues
%
% Args:
%     - delta_od: matrix of double, size: nb_wavelengths x time
%         The NIRS OD measurements
%     - wavelengths: array of double, size: nb_wavelengths
%         Wavelengths of the NIRS OD measurements
%    [- age]: double, default is 25
%         The subject's age
%
% Output: matrix of double, size: nb_wavelengths x time
%     Corrected NIRS OD measurements

% Duncan et al 1996:
% dpf = y_0 + a1 * age^a2
dpf_ref_data = [ ...
    [690, 5.38, 0.049, 0.877]; ... % WL, y_0, a1, a2 
    [744, 5.11, 0.106, 0.723]; ... % WL, y_0, a1, a2 
    [807, 4.99, 0.067, 0.814]; ... % WL, y_0, a1, a2 
    [832, 4.67, 0.062, 0.819]; ... % WL, y_0, a1, a2 
    ];

y0 = interp1(dpf_ref_data(:,1), dpf_ref_data(:,2), wavelengths, ...
             'linear', 'extrap');
a1 = interp1(dpf_ref_data(:,1), dpf_ref_data(:,3), wavelengths, ...
             'linear', 'extrap');
a2 = interp1(dpf_ref_data(:,1), dpf_ref_data(:,4), wavelengths, ...
             'linear', 'extrap');
dpf = y0 + a1 .* age.^a2;

% ages = 10:50;
% for ia=1:length(ages)
%     dpfs(:, ia) = y0 + a1 .* ages(ia).^a2;
% end
% plot(ages, dpfs(1, :), 'r'); hold on;
% plot(ages, dpfs(2, :), 'b');

pvf = 50; % partial volume factor
ppf = dpf / pvf;

nb_samples = size(delta_od, 2);
delta_od_fixed = delta_od ./ repmat(ppf', 1, nb_samples);
end

function delta_od = normalize_nirs(nirs_sig, method)
%% Normalize given nirs signal
% Args:
%    - nirs_sig: matrix of double, size:  nb_wavelengths x nb_samples
%        NIRS signal to normalize
%   [- method]: str, choices are: 'mean' and 'median', default is 'mean'
%        Normalization method.
%        * 'mean': divide given nirs signal by its mean, for each wavelength
%        * 'median': divide given nirs signal by its median, for each wavelength
% 
% Output: matrix of double, size: nb_channels x nb_wavelengths
%    Normalized NIRS signal.

switch method
    case 'mean'
        od_ref = mean(nirs_sig, 2);
    case 'median'
        od_ref = median(nirs_sig, 2);
end

nb_samples = size(nirs_sig, 2);

delta_od = -log( nirs_sig ./ repmat(od_ref, 1, nb_samples) );
end

function distances = cpt_distances(channels, pair_indexes)

distances = zeros(size(pair_indexes, 1), 1);
for ipair=1:size(pair_indexes, 1)
    distances(ipair) = euc_dist(channels(pair_indexes(ipair, 1)).Loc(:,1), ...
                                channels(pair_indexes(ipair, 1)).Loc(:,2));
end
end

function d = euc_dist(p1, p2)
    d = sqrt(sum((p1 - p2).^2));
end

function hb_extinctions = get_hb_extinctions(wavelengths)
%% Return HB extinction coeffecients in water, at the given wavelenths
%% Unit is cm^-1.l.mol^-1
%
% Args:
%    - wavelengths: array of double, size: nb_wavelength
%        Wavelengths for which to return Hb extinction coefficients
%
% Output: matrix of double, size: nb_wavelengths x 2
%    extinction coefficients of HbO (1st column) and HbR (2nd column)
%    
% Notes:
% These values for the molar extinction coefficient e in [cm-1/(moles/liter)] 
% were compiled by Scott Prahl (prahl@ece.ogi.edu) using data from
% W. B. Gratzer, Med. Res. Council Labs, Holly Hill, London
% N. Kollias, Wellman Laboratories, Harvard Medical School, Boston
% To convert this data to absorbance A, multiply the molar extinction e 
% by the molar concentration (x/66500) and the pathlength (1cm here). 
% For example, if x is the number of grams per liter and a 1 cm cuvette is 
% being used, then the absorbance is given by
%
%        (e) [(1/cm)/(moles/liter)] (x) [g/liter] (1) [cm]
%  A =  ---------------------------------------------------
%                          66,500 [g/mole]
%
% using 66,500 as the gram molecular weight of hemoglobin.
% To convert this data to absorption coefficient in (cm-1), multiply by
% the molar concentration and 2.303,
% a = (2.303)* e * x [g/liter]/66,500 [g Hb/mole]
% where x is the number of grams per liter. A typical value of x for 
% whole blood is x=150 g Hb/liter.

%TODO: use same values as Alexis
extinction_hbo_hbr_ref = [
250	106112	112736 ;
252	105552	112736; 
254	107660	112736;
256	109788	113824;
258	112944	115040;
260	116376	116296;
262	120188	117564;
264	124412	118876;
266	128696	120208;
268	133064	121544;
270	136068	122880;
272	137232	123096;
274	138408	121952;
276	137424	120808;
278	135820	119840;
280	131936	118872;
282	127720	117628;
284	122280	114820;
286	116508	112008;
288	108484	107140;
290	104752	98364;
292	98936	91636;
294	88136	85820;
296	79316	77100;
298	70884	69444;
300	65972	64440;
302	63208	61300;
304	61952	58828;
306	62352	56908;
308	62856	57620;
310	63352	59156;
312	65972	62248;
314	69016	65344;
316	72404	68312;
318	75536	71208;
320	78752	74508;
322	82256	78284;
324	85972	82060;
326	89796	85592;
328	93768	88516;
330	97512	90856;
332	100964	93192;
334	103504	95532;
336	104968	99792;
338	106452	104476;
340	107884	108472;
342	109060	110996;
344	110092	113524;
346	109032	116052;
348	107984	118752;
350	106576	122092;
352	105040	125436;
354	103696	128776;
356	101568	132120;
358	97828	133632;
360	94744	134940;
362	92248	136044;
364	89836	136972;
366	88484	137900;
368	87512	138856;
370	88176	139968;
372	91592	141084;
374	95140	142196;
376	98936	143312;
378	103432	144424;
380	109564	145232;
382	116968	145232;
384	125420	148668;
386	135132	153908;
388	148100	159544;
390	167748	167780;
392	189740	180004;
394	212060	191540;
396	231612	202124;
398	248404	212712;
400	266232	223296;
402	284224	236188;
404	308716	253368;
406	354208	270548;
408	422320	287356;
410	466840	303956;
412	500200	321344;
414	524280	342596;
416	521880	363848;
418	515520	385680;
420	480360	407560;
422	431880	429880;
424	376236	461200;
426	326032	481840;
428	283112	500840;
430	246072	528600;
432	214120	552160;
434	165332	552160;
436	132820	547040;
438	119140	501560;
440	102580	413280;
442	92780	363240;
444	81444	282724;
446	76324	237224;
448	67044	173320;
450	62816	103292;
452	58864	62640;
454	53552	36170;
456	49496	30698.8;
458	47496	25886.4;
460	44480	23388.8;
462	41320	20891.2;
464	39807.2	19260.8;
466	37073.2	18142.4;
468	34870.8	17025.6;
470	33209.2	16156.4;
472	31620	15310;
474	30113.6	15048.4;
476	28850.8	14792.8;
478	27718	14657.2;
480	26629.2	14550;
482	25701.6	14881.2;
484	25180.4	15212.4;
486	24669.6	15543.6;
488	24174.8	15898;
490	23684.4	16684;
492	23086.8	17469.6;
494	22457.6	18255.6;
496	21850.4	19041.2;
498	21260	19891.2;
500	20932.8	20862;
502	20596.4	21832.8;
504	20418	22803.6;
506	19946	23774.4;
508	19996	24745.2;
510	20035.2	25773.6;
512	20150.4	26936.8;
514	20429.2	28100;
516	21001.6	29263.2;
518	22509.6	30426.4;
520	24202.4	31589.6;
522	26450.4	32851.2;
524	29269.2	34397.6;
526	32496.4	35944;
528	35990	37490;
530	39956.8	39036.4;
532	43876	40584;
534	46924	42088;
536	49752	43592;
538	51712	45092;
540	53236	46592;
542	53292	48148;
544	52096	49708;
546	49868	51268;
548	46660	52496;
550	43016	53412;
552	39675.2	54080;
554	36815.2	54520;
556	34476.8	54540;
558	33456	54164;
560	32613.2	53788;
562	32620	52276;
564	33915.6	50572;
566	36495.2	48828;
568	40172	46948;
570	44496	45072;
572	49172	43340;
574	53308	41716;
576	55540	40092;
578	54728	38467.6;
580	50104	37020;
582	43304	35676.4;
584	34639.6	34332.8;
586	26600.4	32851.6;
588	19763.2	31075.2;
590	14400.8	28324.4;
592	10468.4	25470;
594	7678.8	22574.8;
596	5683.6	19800;
598	4504.4	17058.4;
600	3200	14677.2;
602	2664	13622.4;
604	2128	12567.6;
606	1789.2	11513.2;
608	1647.6	10477.6;
610	1506	9443.6;
612	1364.4	8591.2;
614	1222.8	7762;
616	1110	7344.8;
618	1026	6927.2;
620	942	6509.6;
622	858	6193.2;
624	774	5906.8;
626	707.6	5620;
628	658.8	5366.8;
630	610	5148.8;
632	561.2	4930.8;
634	512.4	4730.8;
636	478.8	4602.4;
638	460.4	4473.6;
640	442	4345.2;
642	423.6	4216.8;
644	405.2	4088.4;
646	390.4	3965.08;
648	379.2	3857.6;
650	368	3750.12;
652	356.8	3642.64;
654	345.6	3535.16;
656	335.2	3427.68;
658	325.6	3320.2;
660	319.6	3226.56;
662	314	3140.28;
664	308.4	3053.96;
666	302.8	2967.68;
668	298	2881.4;
670	294	2795.12;
672	290	2708.84;
674	285.6	2627.64;
676	282	2554.4;
678	279.2	2481.16;
680	277.6	2407.92;
682	276	2334.68;
684	274.4	2261.48;
686	272.8	2188.24;
688	274.4	2115;
690	276	2051.96;
692	277.6	2000.48;
694	279.2	1949.04;
696	282	1897.56;
698	286	1846.08;
700	290	1794.28;
702	294	1741;
704	298	1687.76;
706	302.8	1634.48;
708	308.4	1583.52;
710	314	1540.48;
712	319.6	1497.4;
714	325.2	1454.36;
716	332	1411.32;
718	340	1368.28;
720	348	1325.88;
722	356	1285.16;
724	364	1244.44;
726	372.4	1203.68;
728	381.2	1152.8;
730	390	1102.2;
732	398.8	1102.2;
734	407.6	1102.2;
736	418.8	1101.76;
738	432.4	1100.48;
740	446	1115.88;
742	459.6	1161.64;
744	473.2	1207.4;
746	487.6	1266.04;
748	502.8	1333.24;
750	518	1405.24;
752	533.2	1515.32;
754	548.4	1541.76;
756	562	1560.48;
758	574	1560.48;
760	586	1548.52;
762	598	1508.44;
764	610	1459.56;
766	622.8	1410.52;
768	636.4	1361.32;
770	650	1311.88;
772	663.6	1262.44;
774	677.2	1213;
776	689.2	1163.56;
778	699.6	1114.8;
780	710	1075.44;
782	720.4	1036.08;
784	730.8	996.72;
786	740	957.36;
788	748	921.8;
790	756	890.8;
792	764	859.8;
794	772	828.8;
796	786.4	802.96;
798	807.2	782.36;
800	816	761.72;
802	828	743.84;
804	836	737.08;
806	844	730.28;
808	856	723.52;
810	864	717.08;
812	872	711.84;
814	880	706.6;
816	887.2	701.32;
818	901.6	696.08;
820	916	693.76;
822	930.4	693.6;
824	944.8	693.48;
826	956.4	693.32;
828	965.2	693.2;
830	974	693.04;
832	982.8	692.92;
834	991.6	692.76;
836	1001.2	692.64;
838	1011.6	692.48;
840	1022	692.36;
842	1032.4	692.2;
844	1042.8	691.96;
846	1050	691.76;
848	1054	691.52;
850	1058	691.32;
852	1062	691.08;
854	1066	690.88;
856	1072.8	690.64;
858	1082.4	692.44;
860	1092	694.32;
862	1101.6	696.2;
864	1111.2	698.04;
866	1118.4	699.92;
868	1123.2	701.8;
870	1128	705.84;
872	1132.8	709.96;
874	1137.6	714.08;
876	1142.8	718.2;
878	1148.4	722.32;
880	1154	726.44;
882	1159.6	729.84;
884	1165.2	733.2;
886	1170	736.6;
888	1174	739.96;
890	1178	743.6;
892	1182	747.24;
894	1186	750.88;
896	1190	754.52;
898	1194	758.16;
900	1198	761.84;
902	1202	765.04;
904	1206	767.44;
906	1209.2	769.8;
908	1211.6	772.16;
910	1214	774.56;
912	1216.4	776.92;
914	1218.8	778.4;
916	1220.8	778.04;
918	1222.4	777.72;
920	1224	777.36;
922	1225.6	777.04;
924	1227.2	776.64;
926	1226.8	772.36;
928	1224.4	768.08;
930	1222	763.84;
932	1219.6	752.28;
934	1217.2	737.56;
936	1215.6	722.88;
938	1214.8	708.16;
940	1214	693.44;
942	1213.2	678.72;
944	1212.4	660.52;
946	1210.4	641.08;
948	1207.2	621.64;
950	1204	602.24;
952	1200.8	583.4;
954	1197.6	568.92;
956	1194	554.48;
958	1190	540.04;
960	1186	525.56;
962	1182	511.12;
964	1178	495.36;
966	1173.2	473.32;
968	1167.6	451.32;
970	1162	429.32;
972	1156.4	415.28;
974	1150.8	402.28;
976	1144	389.288;
978	1136	374.944;
980	1128	359.656;
982	1120	344.372;
984	1112	329.084;
986	1102.4	313.796;
988	1091.2	298.508;
990	1080	283.22;
992	1068.8	267.932;
994	1057.6	252.648;
996	1046.4	237.36;
998	1035.2	222.072;
1000	1024	206.784;
];

extinction_hbo_hbr_ref(:,2) = extinction_hbo_hbr_ref(:,2) * 2.303;
extinction_hbo_hbr_ref(:,3) = extinction_hbo_hbr_ref(:,3) * 2.303;

if any(wavelengths > extinction_hbo_hbr_ref(end,1)) || ...
    any(wavelengths < extinction_hbo_hbr_ref(1,1))
    raise(MException('NSTValueError', ['Hb exctinction not available for '...
                     'input wavelengths:' num2str(wavelengths)]));
end

nb_wavelengths = length(wavelengths);
hb_extinctions = zeros(nb_wavelengths, 2);
for ihb=1:2
    for iwl=1:nb_wavelengths
        hb_extinctions(iwl, ihb) = interp1(extinction_hbo_hbr_ref(:,1), ...
                                           extinction_hbo_hbr_ref(:,ihb+1), ...
                                           wavelengths(iwl));
    end
end

end

function [paired_nirs, pair_names, pair_loc, pair_indexes] = ...
    group_paired_channels(nirs, channel_def)
%% Reshape the given nirs signal to group paired channels, explode 
%% channel data according to pairs
% Args
%    - nirs_sig: matrix of double, size: nb_samples x nb_channels
%        Nirs signal time-series.
%    - channel_def: struct
%        Defintion of channels as given by brainstorm
%        Used fields: Nirs.Wavelengths, Channel
%
% ASSUME: data contain only wavelength-related channels (no AUX etc.)
%
% TOCHECK WARNING: uses containers.Map which is available with matlab > v2008
%
%  Outputs: 
%     - paired_nirs: array of double, size: nb_pairs x nb_wavelengths xnb_samples
%         Nirs signals, regrouped by pair
%     - pair_names: cell array of str, size: nb_pairs
%         Pair names, format: SXDX
%     - pair_loc: array of double, size: nb_pairs x 3 x 2
%         Pair localization (coordinates of source and detector)
%     - pair_indexes: matrix of double, size: nb_pairs x nb_wavelengths
%         Input channel indexes grouped by pairs
%

nb_wavelengths = length(channel_def.Nirs.Wavelengths);
nb_samples = size(nirs, 1);

pair_to_chans = containers.Map();
for ichan=1:length(channel_def.Channel)
    chan_name = channel_def.Channel(ichan).Name;
    iwl = strfind(chan_name, 'WL'); 
    pair_name = chan_name(1:iwl-1);
    %TODO: keep only channel that are wavelength-related
    wl = str2double(chan_name(iwl+2:end));
    if pair_to_chans.isKey(pair_name)
        wla = pair_to_chans(pair_name);
    else
        wla = zeros(1, nb_wavelengths);
    end
    wla(channel_def.Nirs.Wavelengths==wl) = ichan;
    pair_to_chans(pair_name) = wla;
end
nb_pairs = length(channel_def.Channel) / nb_wavelengths;
pair_names = pair_to_chans.keys;
pair_indexes = zeros(nb_pairs, nb_wavelengths);
pair_loc = zeros(nb_pairs, 3, 2);
paired_nirs = zeros(nb_pairs, nb_wavelengths, nb_samples);
for ipair=1:nb_pairs
    p_indexes = pair_to_chans(pair_names{ipair});
    pair_indexes(ipair, :) = p_indexes;
    paired_nirs(ipair, :, :) = nirs(:, p_indexes)';
    pair_loc(ipair, : , :) = channel_def.Channel(pair_indexes(ipair, 1)).Loc;
end

end

