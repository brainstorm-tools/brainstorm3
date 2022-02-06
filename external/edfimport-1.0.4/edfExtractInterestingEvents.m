function [Trials]= edfExtractInterestingEvents(Trials, TrialStartMarker)
%%  edfImport library v1.0 
%  Alexander Pastukhov 
%  kobi.nat.uni-magdeburg.de/edfImport
%  email: pastukhov.alexander@gmail.com
%  
%  edfExtractInterestingEvents
%  Extract fixations, saccades, blinks and button presses from events and
%  places them into new fields within Trial structure.  
%
%  Syntax:
%    Trials= edfExtractInterestingEvents(Trials [, TrialStartMarker])
%  Input:
%    Trials - trials structure as return by edfImport
%    TrialStartMarker - a REGULAR EXPRESSION with an optional trial start
%    marker. By default start of the trial is identified using '!MODE
%    RECORD' event. 
%
%  Description"
%    Trials= edfExtractInterestingEvents(Trials, [TrialStartMarker])} extact fixations,
%    saccades, blinks and button presses from events and places them, respectively, into
%    Fixations, Saccades, Blinks and Buttons field in the updated Trials structure.
%    New substructures contain the following fields (see details in EDF API
%    manual):     
%    * Fixations: eye, sttime, entime, time, gavx, gavy, PixInDegX,
%      PixInDegY 
%    * Saccades: eye, sttime, entime, time, gstx, gsty, genx, geny, avel,
%      pvel, ampl, phi, PixInDegX, PixInDegY 
%    * Blinks:  eye, sttime, entime, time
%    * Buttons: ID, Pressed, time

%% figuring out trials start event
if (~exist('TrialStartMarker', 'var') || isempty(TrialStartMarker))
  TrialStartMarker= '!MODE RECORD';
end;

for iTrial= 1:length(Trials),
%   [iTrial]
%% preparing service variables and arrays
  %% saccades
  iS= 1;
  Saccades= [];
  LeftSaccadeStart= 0;
  RightSaccadeStart= 0;
  
  %% fixations
  iF= 1;
  Fixations= [];
  LeftFixationStart= 0;
  RightFixationStart= 0;
  
  %% blanks
  iB= 1;
  Blanks= [];
  LeftBlankStart= 0;
  RightBlankStart= 0;
  
  %% button events
  iBut= 1;
  Buttons= [];
  ButtonState= [0 0 0 0];
  
  Events= Trials(iTrial).Events;
  
%% finding start of recording
  Trials(iTrial).StartTime= edfFindTrialRecordingStart(Events, TrialStartMarker);
  StartTime= Trials(iTrial).StartTime;
  if (isempty(StartTime))
    continue;
  end;
  
%% going through all events
  for iE= 1:length(Trials(iTrial).Events.type),
    switch (Trials(iTrial).Events.type(iE))
      case 3 %% Blank start
        if (Trials(iTrial).Events.eye(iE))
          RightBlankStart= Trials(iTrial).Events.sttime(iE);
        else
          LeftBlankStart= Trials(iTrial).Events.sttime(iE);
        end;
      case 4 %% Blank end
        Blanks.eye(iB)= Events.eye(iE);
        if (Blanks.eye(iB))
          BlankStart= RightBlankStart;
        else
          BlankStart= LeftBlankStart;
        end;
        Blanks.sttime(iB)= BlankStart-StartTime;
        Blanks.entime(iB)= Events.entime(iE)-StartTime;
        Blanks.time(iB)= Blanks.entime(iB)-Blanks.sttime(iB)+1;
        iB= iB+1;
      case 5 %% Saccade start
        if (Events.eye(iE))
          RightSaccadeStart= Events.sttime(iE);
        else
          LeftSaccadeStart= Events.sttime(iE);
        end;
      case 6 %% Saccade end
        Saccades.eye(iS)= Events.eye(iE);
        if (Saccades.eye(iS))
          SaccadeStart= RightSaccadeStart;
        else
          SaccadeStart= LeftSaccadeStart;
        end;
        Saccades.sttime(iS)= SaccadeStart-StartTime;
        Saccades.entime(iS)= Events.entime(iE)-StartTime;
        Saccades.time(iS)= Saccades.entime(iS)-Saccades.sttime(iS)+1;
        Saccades.gstx(iS)= Events.gstx(iE);
        Saccades.gsty(iS)= Events.gsty(iE);
        Saccades.genx(iS)= Events.genx(iE);
        Saccades.geny(iS)= Events.geny(iE);
        Saccades.avel(iS)= Events.avel(iE);    
        Saccades.pvel(iS)= Events.pvel(iE);
        Saccades.ampl(iS)= hypot((Saccades.genx(iS)-Saccades.gstx(iS))/mean([Events.eupd_x(iE) Events.supd_x(iE)]), (Saccades.geny(iS)-Saccades.gsty(iS))/mean([Events.eupd_y(iE) Events.supd_y(iE)]));
        Saccades.phi(iS)= atan2(Saccades.geny(iS)-Saccades.gsty(iS), Saccades.genx(iS)-Saccades.gstx(iS))*180/pi;
        Saccades.PixInDegX(iS)= mean([Events.supd_x(iE) Events.eupd_x(iE)]);
        Saccades.PixInDegY(iS)= mean([Events.supd_y(iE) Events.eupd_y(iE)]);
        iS= iS+1;
      case 7 %% Fixation start
        if (Events.eye(iE))
          RightFixationStart= Events.sttime(iE);
        else
          LeftFixationStart= Events.sttime(iE);
        end;
      case 8 %% Fixation end
        Fixations.eye(iF)= Events.eye(iE);
        if (Fixations.eye(iF))
          FixationStart= RightFixationStart;
        else
          FixationStart= LeftFixationStart;
        end;
        Fixations.sttime(iF)= FixationStart-StartTime;
        Fixations.entime(iF)= Events.entime(iE)-StartTime;
        Fixations.time(iF)= Fixations.entime(iF)-Fixations.sttime(iF)+1;
        Fixations.gavx(iF)= Events.gavx(iE);
        Fixations.gavy(iF)= Events.gavy(iE);
        Fixations.PixInDegX(iF)= mean([Events.supd_x(iE) Events.eupd_x(iE)]);
        Fixations.PixInDegY(iF)= mean([Events.supd_y(iE) Events.eupd_y(iE)]);
        iF= iF+1;
      case 25 %% Change in button state
        if (Events.sttime(iE)-StartTime>0)
          for iButton= 1:4,
            NewButtonState= bitand(Events.buttons(iE), 2^(iButton-1))>0;
            if (NewButtonState~=ButtonState(iButton))
              Buttons(iBut).ID= iButton;
              Buttons(iBut).Pressed= NewButtonState;
              Buttons(iBut).time=  Events.sttime(iE)-StartTime;
              iBut= iBut+1;
            end;
            ButtonState(iButton)= NewButtonState;
          end;
        end;
    end;
  end;
  
%% copying results
  Trials(iTrial).Fixations= Fixations;
  Trials(iTrial).Saccades= Saccades;
  Trials(iTrial).Blinks= Blanks;
  Trials(iTrial).Buttons= Buttons;
end;
