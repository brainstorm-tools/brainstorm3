function [Trials]= edfExtractMicrosaccades(Trials, VelocityBraketMS, VelocityThreshold, MinimalDurationMS, MinimalSeparationMS)
%%  edfImport library v1.0 
%  Alexander Pastukhov 
%  kobi.nat.uni-magdeburg.de/edfImport
%  email: pastukhov.alexander@gmail.com
%    
%  edfExtractMicrosaccades
%  Extracts microsaccades from the raw eye positions data using algorithm
%  described in Engbert & Kliegl (2003). If you use this function, please
%  cite: Engbert, R. and R. Kliegl (2003). "Microsaccades uncover the orientation of covert attention." Vision Res 43(9): 1035-45.
%
%  Syntax:
%    Trials= edfExtractMicrosaccadesForTrial(Trials,VelocityBraketMS, VelocityThreshold, MinimalDurationMS, MinimalSeparationMS)
%    Trials= edfExtractMicrosaccadesForTrial(Trials)
%
%  Description:
%    Extracts microsaccades using raw eye positions. This requires that
%    Samples field exists (i.e. samples were imported) and the following
%    fields are present: time, gx, gy. Refresh rate of the camera for recording
%    is taken from Trials().Header.rec.sample_rate field.    
%
%    Additional options and their default values (used if the option is
%    omitted), for more details consult Engbert \& Kliegl (2003). 
%    * VelocityBraketMS: time span around current sample with which to
%      compute the velocity in milliseconds. Default: 20 ms.
%    * VelocityThreshold: velocity threshold for microsaccade detection in
%      medians. Default: 6.
%    * MinimalDurationMS: minimal microsaccade duration in milliseconds.
%      Default: 12 ms.
%    * MinimalSeparationMS: minimal time in milliseconds allowed between
%      two microsaccades, otherwise they are merged. Default: 12 ms.
%
%     For information on the appended Microsaccades structure consult the
%     manual. 

%% using default values, if some parameters are empty or undefined
if (~exist('VelocityBraketMS', 'var') || isempty(VelocityBraketMS))
%   disp('No value for velocity braket to compute velocity. Using default value: 20 ms.');
  VelocityBraketMS= 20;
end;
if (~exist('VelocityThreshold', 'var') || isempty(VelocityThreshold))
%   disp('No value for velocity threshold. Using default value: 6 (x median).');
  VelocityThreshold= 6;
end;
if (~exist('MinimalDurationMS', 'var') || isempty(MinimalDurationMS))
%   disp('No value for minimal saccade duration. Using default value: 12 ms.');
  MinimalDurationMS= 12;
end;
if (~exist('MinimalSeparationMS', 'var') || isempty(MinimalSeparationMS))
%   disp('No value for minimal separation between saccades. Using default value: 12 ms.');
  MinimalSeparationMS= 12;
end;

%% doing trial-by-trial analysis
for iTrial= 1:length(Trials),
  %% getting data
  DeltaT= 1000/Trials(iTrial).Header.rec.sample_rate;
 
  %% checking that data is where
  if (isfield(Trials(iTrial), 'Samples'))
    Samples= Trials(iTrial).Samples;
  else
    throw(MException('edfMATLAB:edfExtractMicrosaccades:NoSamplesField', 'No Samples field in for trial %d', iTrial));    
  end;
  if (~isfield(Samples, 'time'))
    throw(MException('edfMATLAB:edfExtractMicrosaccades:NoTimeField', 'No "time" field in Samples for the trial %d', iTrial));    
  end;
  if (~isfield(Samples, 'gx'))
    throw(MException('edfMATLAB:edfExtractMicrosaccades:NoGXField', 'No "gx" field in Samples for the trial %d', iTrial));    
  end;
  if (~isfield(Samples, 'gy'))
    throw(MException('edfMATLAB:edfExtractMicrosaccades:NoGYField', 'No "gy" field in Samples for the trial %d', iTrial));    
  end;

  %% computing velocities
  BracketInSamples= ceil((VelocityBraketMS/DeltaT-1)/2);
  CommonFactor= 2*sum(1:BracketInSamples)*DeltaT/1000;
  Samples.velx= zeros(size(Samples.gx));
  for iEye= 1:2,
    Samples.normgx(iEye, :)= Samples.gx(iEye, :)-mean(Samples.gx(iEye, :));
    Samples.normgy(iEye, :)= Samples.gy(iEye, :)-mean(Samples.gy(iEye, :));
  end;
  Samples.vely= zeros(size(Samples.gx));
  for iT= BracketInSamples+1:size(Samples.gx, 2)-BracketInSamples,
    Samples.velx(:, iT)= sum(-Samples.gx(:, iT-[1:BracketInSamples])+Samples.gx(:, iT+[1:BracketInSamples]), 2)./CommonFactor;
    Samples.vely(:, iT)= sum(-Samples.gy(:, iT-[1:BracketInSamples])+Samples.gy(:, iT+[1:BracketInSamples]), 2)./CommonFactor;
  end;
  Samples.vel2d= hypot(Samples.velx, Samples.vely);
  Velocities= Samples.vel2d;

  %% computing velocity thresholds
  ThresholdX= VelocityThreshold.*sqrt( median(Samples.velx.^2, 2) - (median(Samples.velx, 2).^2) );
  ThresholdY= VelocityThreshold.*sqrt( median(Samples.vely.^2, 2) - (median(Samples.vely, 2).^2) );
  for iEye= 1:2,
    Samples.velInThreshold(iEye, :)= hypot(Samples.velx(iEye, :)./ThresholdX(iEye), Samples.vely(iEye, :)./ThresholdY(iEye));
  end;

  %% locating possible events for each eye separately
  %  merging saccades into a longer ones if temporal separation is small
  EyeSaccades= [];
  Saccades= [];
  Nothing= 0;
  for iEye= 1:2,
      iHighSpeed= find(Samples.velInThreshold(iEye, :)>1);
      if (isempty(iHighSpeed))
        Nothing= 1;
        break;
      end;

      iS= 1;
      EyeSaccades(iEye).Start= [];
      EyeSaccades(iEye).End= [];
      EyeSaccades(iEye).Merged= [];
      CurrentStart= iHighSpeed(1);
      Duration= 1;
      for iHigh= 2:length(iHighSpeed),
        if (iHighSpeed(iHigh)~=iHighSpeed(iHigh-1)+1) %% discontinuity
          if (DeltaT*(iHighSpeed(iHigh-1)-CurrentStart+1)>=MinimalDurationMS) 
          %% if sequence is long enough to be counted as saccade
            if (iS==1 || DeltaT*(CurrentStart-EyeSaccades(iEye).End(iS-1)+1)>=MinimalSeparationMS) 
            %% first saccade or saccade after a sufficiently long time
              EyeSaccades(iEye).Start(iS)= CurrentStart; 
              EyeSaccades(iEye).End(iS)= iHighSpeed(iHigh-1); %*DeltaT;
              EyeSaccades(iEye).Merged(iS)= 0;
              iS= iS+1;
            else
              %% otherwise - appending a previous saccade, so it is longer
              EyeSaccades(iEye).End(iS-1)= iHighSpeed(iHigh-1); %*DeltaT;
              EyeSaccades(iEye).Merged(iS-1)= 1;
            end;
          end;

          %% starting the next sequence
          CurrentStart= iHighSpeed(iHigh);
        end;
      end;

      %% wraping up the last one (if it is really long)
      iHigh= length(iHighSpeed)+1;
      if (DeltaT*(iHighSpeed(iHigh-1)-CurrentStart+1)>=MinimalDurationMS) 
      %% if sequence is long enough to be counted as saccade
        if (iS==1 || DeltaT*(CurrentStart-EyeSaccades(iEye).End(iS-1)+1)>=MinimalSeparationMS) 
        %% first saccade or saccade after a sufficiently long time
          EyeSaccades(iEye).Start(iS)= CurrentStart;
          EyeSaccades(iEye).End(iS)= iHighSpeed(iHigh-1);
          EyeSaccades(iEye).Merged(iS)= 0;
          iS= iS+1;
        else
          %% otherwise - appending a previous saccade, so it is longer
          EyeSaccades(iEye).End(iS-1)= iHighSpeed(iHigh-1);
          EyeSaccades(iEye).Merged(iS-1)= 1;
        end;
      end;
  end;
  
  if (Nothing)
    continue;
  end;

  %% computing saccade's parameters
  for iEye= 1:2,
    for iS= 1:length(EyeSaccades(iEye).Start),
      EyeSaccades(iEye).vPeak(iS)= max(Samples.vel2d(iEye, EyeSaccades(iEye).Start(iS):EyeSaccades(iEye).End(iS)));
      EyeSaccades(iEye).DeltaX(iS)= Samples.normgx(iEye, EyeSaccades(iEye).End(iS))- Samples.normgx(iEye, EyeSaccades(iEye).Start(iS));
      EyeSaccades(iEye).DeltaY(iS)= Samples.normgy(iEye, EyeSaccades(iEye).End(iS))- Samples.normgy(iEye, EyeSaccades(iEye).Start(iS));
      EyeSaccades(iEye).Amplitude(iS)= hypot(EyeSaccades(iEye).DeltaX(iS), EyeSaccades(iEye).DeltaY(iS));
      EyeSaccades(iEye).Phi(iS)= atan2(EyeSaccades(iEye).DeltaY(iS), EyeSaccades(iEye).DeltaX(iS));
    end;
  end;


  %% making sure that "left" eye has fewer microsaccades
  if (length(EyeSaccades(2).Start)<length(EyeSaccades(1).Start))
    EyeTemp= EyeSaccades(2);
    EyeSaccades(2)= EyeSaccades(1);
    EyeSaccades(1)= EyeTemp;
  end;

  %% checking binocular correspondence
  Saccades= EyeSaccades(1);
  iBadLeftEyeSaccades= [];
  for iLS= 1:length(Saccades.Start),
    iOverlap= find(EyeSaccades(2).Start<=Saccades.End(iLS) & EyeSaccades(2).End>=Saccades.Start(iLS));
    if (~isempty(iOverlap))

      Saccades.Start(iLS)= min([Saccades.Start(iLS) EyeSaccades(2).Start(iOverlap)]);
      Saccades.End(iLS)= max([Saccades.End(iLS) EyeSaccades(2).End(iOverlap)]);
      Saccades.Merged(iLS)= max([Saccades.Merged(iLS) EyeSaccades(2).Merged(iOverlap)]);
      Saccades.vPeak(iLS)= mean([Saccades.vPeak(iLS) EyeSaccades(2).vPeak(iOverlap)]);
      Saccades.Amplitude(iLS)= mean([Saccades.Amplitude(iLS) EyeSaccades(2).Amplitude(iOverlap)]);
      Saccades.DeltaX(iLS)= sum([Saccades.DeltaX(iLS) EyeSaccades(2).DeltaX(iOverlap)]);
      Saccades.DeltaY(iLS)= sum([Saccades.DeltaY(iLS) EyeSaccades(2).DeltaY(iOverlap)]);
      Saccades.Phi(iLS)= atan2(Saccades.DeltaY(iLS), Saccades.DeltaX(iLS));
    else
      iBadLeftEyeSaccades= [iBadLeftEyeSaccades iLS];
    end;
  end;

  if (isempty(Saccades.Start))
    continue;
  end;

  Saccades.Start(iBadLeftEyeSaccades)= [];
  Saccades.End(iBadLeftEyeSaccades)= [];
  Saccades.Merged(iBadLeftEyeSaccades)= [];
  Saccades.vPeak(iBadLeftEyeSaccades)= [];
  Saccades.DeltaX(iBadLeftEyeSaccades)= [];
  Saccades.DeltaY(iBadLeftEyeSaccades)= [];
  Saccades.Amplitude(iBadLeftEyeSaccades)= [];
  Saccades.Phi(iBadLeftEyeSaccades)= [];

  %% re-checking whether (now binocular) saccades are sufficiently far apart
  %  in time
  iS= 2;
  while (iS<length(Saccades.Start))
    if (DeltaT*(Saccades.Start(iS)-Saccades.End(iS-1)+1)<MinimalSeparationMS)
      %% appending first saccade
      Saccades.End(iS-1)= Saccades.End(iS);
      Saccades.Merged(iS-1)= 1;

      %% erasing the second one
      Saccades.Start(iS)= [];
      Saccades.End(iS)= [];
      Saccades.Merged(iS)= [];
      Saccades.vPeak(iS)= [];
      Saccades.DeltaX(iS)= [];
      Saccades.DeltaY(iS)= [];
      Saccades.Amplitude(iS)= [];
      Saccades.Phi(iS)= [];
    else
      iS= iS+1;
    end;
  end;

  %% updating time
  for iS= 1:length(Saccades.Start),
    Saccades.StartTime(iS)= Samples.time(Saccades.Start(iS));
    Saccades.EndTime(iS)= Samples.time(Saccades.End(iS));
    Saccades.Duration(iS)= Saccades.EndTime(iS)-Saccades.StartTime(iS);
  end;

  %% copying
  Trials(iTrial).Microsaccades= Saccades;
end;
