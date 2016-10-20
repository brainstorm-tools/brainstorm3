function [RecordingStartTime]= edfFindTrialRecordingStart(Events, TrialStartMarker)
%%  edfImport library v1.0 
%  Alexander Pastukhov 
%  kobi.nat.uni-magdeburg.de/edfImport
%  email: pastukhov.alexander@gmail.com
%  
%  edfFindTrialRecordingStart
%  Returns an absolute time of the recording start ('!MORE RECORD' event) for each trial.
%  Note: if Events from more than one trial are passed, only the first one
%  is returned
%  Syntax:
%    [RecordingStartTime]= edfFindTrialRecordingStart(Events)
%  Input:
%    Events - array of FEVENT structures (see "Eyelink EDF Access API" for details)
%  Output:
%    RecordingStartTime - absolute time when recording started for each
%    trial

%% just in case there is some old that does not explicitely pass the marker
if (~exist('TrialStartMarker', 'var') || isempty(TrialStartMarker))
  TrialStartMarker= '!MODE RECORD';
end;


RecordingStartTime= [];
for iE= 1:length(Events.message)
  if (~isempty(regexp(Events.message{iE}, TrialStartMarker)))
    RecordingStartTime= Events.sttime(iE);
    break;
  end;
end;