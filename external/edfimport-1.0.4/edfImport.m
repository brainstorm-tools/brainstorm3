function [Trials, Preamble]= edfImport(Filename, Options, SampleFields, TrimSamplesToCorrectNumber)
%%  edfImport library v1.0 
%  Alexander Pastukhov 
%  kobi.nat.uni-magdeburg.de/edfImport
%  email: pastukhov.alexander@gmail.com
%
%  Imports events and/or samples from the EDF file.
% 
%  Syntax:
% 	 Trials= edfImport(Filename, Options, SampleFields, TrimSamplesToCorrectNumber)
% 	 Trials= edfImport(Filename, Options)
% 	 Trials= edfImport(Filename)
% 	 [Trials, Preamble]= edfImport(...)
%
%  Description:
%    Trials= edfImport(Filename, Options, SampleFields,
%    TrimSamplesToCorrectNumber) imports events 
%    and/or samples from the file Filename. Options argument is a vector 
%    with following flags [consistency load_events load_samples]. Where  
%    * consistency:
%        0: no consistency check
%        1: check consistency and report (default)
%        2: check consistency and fix
%    * load_events
%        0: do not load events
%        1: load events                  (default)
%    * load_samples
%        0: do not load samples          (default)
%        1: load samples         
%
%    SampleFields is a space-separated list of FSAMPLE structure fields to
%    be imported. If load_samples is 0 this argument is ignored. To import
%    all fields omit SampleField argument or pass an empty string.
%
%    TrimSamplesToCorrectNumber (default: true): truncates samples to the
%    real number of imported samples. Arrays may be longer as they are
%    pre-allocated by computing number of samples based on recording
%    duration and sampling frequency. Typically, you may get one (last)
%    empty sample.
%
%    Trials= edfImport(Filename, Options) if load_samples is 1 - imports
%    all FSAMPLE fields. 
% 
%    Trials= edfImport(Filename) uses default Options= [1 1 0].
% 
%    [Trials, Preamble]= edfImport(...) additionally imports Preamble of
%    the EDF file (see EDF API manual for details).  

%% checking that Filename argument exists
if (~exist('Filename', 'var') || isempty(Filename))
  throw(MException('edfImport:UndefinedFilename', 'Undefined filename argument'));
end;

%% checking that Filename is a string
if (~ischar(Filename))
  throw(MException('edfImport:BadFilename', 'Filename argument must be a string'));
end;
  
%% adding file extension if necessary 
if (isempty(regexp(Filename, '.edf$')))
  Filename= [Filename '.edf'];
end;

%% checking that file exists
if (isempty(dir(Filename)))
  throw(MException('edfImport:FileNotFound', sprintf('File "%s" not found.', Filename)));
end;
  
%% checking options validity or using defaults
if (exist('Options', 'var') && ~isempty(Options))
  %% checking number of dimensions
  if (length(size(Options))>2)
    throw(MException('edfMATLAB:edfImport:BadOptionsArray', 'Bad EDF library option array size, see help for details'));    
  end;
  
  %% checking dimensions
  if ~((size(Options, 1)==3 && size(Options, 2)==1) ||  (size(Options, 1)==1 && size(Options, 2)==3))
    throw(MException('edfMATLAB:edfImport:BadOptions', 'Bad EDF library option array size, see help for details'));    
  end;
  
  %% checking range
  if (~isempty(find(Options<0)) || Options(1)>2 || Options(2)>1 || Options(3)>1)
    throw(MException('edfMATLAB:edfImport:BadOptionsRange', 'Bad EDF library option values range, see help for details'));    
  end;
  
  %% checking that values are integer
  OptionsFrac= Options-floor(Options);
  if (max(OptionsFrac)~=0)
    throw(MException('edfMATLAB:edfImport:BadOptionsValues', 'EDF library option values are non integer, see help for details'));    
  end;
else
  %% using default: check consistency and report, import Events
  Options= [1 1 0];
end;

%% checking selected fields
if (exist('SampleFields') && ~isempty(SampleFields))
  SampleFieldsFlag= edfSelectSampleFields(SampleFields);
else
  %% default - all the fields
  SampleFieldsFlag= ones(1, 29); 
end;

%% checking whether we should truncate samples to their real number
if (~exist('TrimSamplesToCorrectNumber', 'var') || isempty(TrimSamplesToCorrectNumber))
  TrimSamplesToCorrectNumber= true;
end;

%% calling mex-function
[Trials, Preamble]= edfMexImport(Filename, Options, SampleFieldsFlag);

%% clearing up unused fields
if ((Options(2)==0) && isfield(Trials, 'Events'))
  Trials= rmfield(Trials, 'Events');
end;
if ((Options(3)==0) && isfield(Trials, 'Samples'))
  Trials= rmfield(Trials, 'Samples');
end;

%% truncating samples, if required
if ((Options(3)==1) && isfield(Trials, 'Samples'))
  fprintf('Truncating samples to exclude empty ones\n');
  
  FieldsList= fieldnames(Trials(1).Samples);
  for iTrial= 1:numel(Trials),
    for iField= 2:numel(FieldsList),
      Trials(iTrial).Samples.(FieldsList{iField})(:, Trials(iTrial).Samples.RealNumberOfSamples+1:end)= [];
    end;
  end;
end;
  
