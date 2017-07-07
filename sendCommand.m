function [] = sendCommand(s, cmd, varargin)
% sends a command to the arduino through the serial port s
%
% s is the serial port object for the serial connection
% note: serial port must be open first
%
% cmd is the command that we want to send, which can be one of the
% following strings:
% - 'start' : this starts the antenna characterization.  Can send
% additional parameter 'Axis' (see below) and 'NumMeasurements' (see below)
%
% - 'stop' : this stops the current characterization
%
% - 'pause' : pauses the current characterization
%
% - 'zero' : sets the current position of the motor to 0 degrees.  Can send
% additional parameter 'Axis' (see below) to specify an axis to zero
%
% - 'reset' : resets the motors to the start position (0 degrees).  Can
% send additional parameter 'Axis' (see below) to specify an axis to reset
%
% - 'move' : moves the motors by a single step in a given direction.  Can
% send additional parameters 'Axis' (see below) to specify an axis and
% 'Direction' (see below) to specify a direction and 'NumSteps' for the
% number of steps to move
%
% - 'configure' : sends step configuration information to the arduino.
% Must set additional 'StepIncrement', 'StepSize', 'Start', and 'End' (see 
% below) parameters.  Can set additional 'Axis' (see below' to specify the
% axis to apply the configuration to.
%
% - 'moveto' : moves to motors to a specific angle.  Sends additional
% parameters 'Axis' (see below) to specify the axis of control and 'Start'
% to specify the angle to which to move to.
%
% - 'setphase' : sets the desired phase for each of the phase shifters for
% each of the 3 antennas on the beam steering board.
%
% Additional Parameters:
% - 'Axis': the axis for a command to apply to.  If not set will default to
% commanding both axes.  Can be one of: 'both', 'azimuth', or 'elevation'
%
% - 'Direction' : sets the direction for the command to be executed in.
% Can be either 'Clockwise' or 'CounterClockwise'
%
% - 'StepSize' : the size to use for a single step.  Can be
% one of '1/8', '1/4', '1/2', or '1'.  Note these are not degrees, but
% rather a parameter of the motor (a full step ('1') is 1.8 degrees).
%
% - 'MeasurementIncrement' : the angle to move for each measurement for the
% automated sequence (in degrees).
%
% - 'Start' : the angle at which to start the run for the specified axis in
% degree
%
% - 'End' : the angle at which to stop the run for the specified axis.
% This is limited to either 90 deg (for Elevation) or 360 def (for Azimuth)
%
% - 'NumMeasurements' : the number of measurements to make at each step
%
% - 'NumSteps' : the number of steps to move
%
% - 'Phases' : the phase (in degrees) to command the phase shifters.  Note
% that uncless the value is a multiple of 1.4, some rounding will occur,
% since the phase shifters can only step in increments of 1.4 degrees.
%

% if the serial port is closed, don't even bother proceeding
if strcmp(s.Status, 'closed')
    % throw some sort of error here???
    fprintf('serial port is closed!!!  Open serial port!\n');
    return;
end

% some constants that are needed

% the command type enum value
CMD_START = 0;
CMD_STOP = 1;
CMD_PAUSE = 2;
CMD_ZERO = 3;
CMD_RESET = 4;
CMD_MOVE = 5;
CMD_CONFIGURE = 6;
CMD_MOVE_TO = 7;
CMD_SET_PHASE = 8;

% the axis type enum value
AXIS_BOTH = 0;
AXIS_AZIMUTH = 1;
AXIS_ELEVATION = 2;

% the step size enum value
STEP_EIGTH = 0;
STEP_QUARTER = 1;
STEP_HALF = 2;
STEP_FULL = 3;

axes = {'both', 'azimuth', 'elevation'};
directions = {'clockwise', 'counterclockwise'};
stepSizes = {'1/8', '1/4', '1/2', '1'};

% parse the variable input params
params = inputParser;
params.addParameter('Axis', 'both');
params.addParameter('Direction', 'clockwise');
params.addParameter('StepSize', '1/8');
params.addParameter('MeasurementIncrement', 1.8);
params.addParameter('Start', 0);
params.addParameter('End', 90);
params.addParameter('NumMeasurements', 10);
params.addParameter('NumSteps', 1);
params.addParameter('Phases', [0 0 0]);
params.parse(varargin{:});

axis = params.Results.Axis;
dir = params.Results.Direction;
step = params.Results.StepSize;
measInc = params.Results.MeasurementIncrement;
startAngle = params.Results.Start*1e6;
endAngle = params.Results.End*1e6;
nmeas = params.Results.NumMeasurements;
numSteps = params.Results.NumSteps;
phases = params.Results.Phases;

% check to make sure the axis entered is valid
axisCmp = strcmpi(axis, axes);
if ~any(axisCmp)
    error('Invalid Axis Option');
end
axisValue = find(axisCmp == 1) - 1;

% check to make sure dir entered is valid
dirCmp = strcmpi(dir, directions);
if ~any(dirCmp)
    error('Invalid Direction Option');
end
dirValue = find(dirCmp == 1) - 1;

% check to make sure step size is valid
stepCmp = strcmpi(step, stepSizes);
if ~any(stepCmp)
    error('Invalid Step Size Option');
end
stepValue = find(stepCmp == 1) - 1;

% need to convert from phase to phase shift value (multiple of 1.4)
% also need to make sure that the value is positive between 0 and 360
% TODO: maybe do this somewhere else, but then need to rename the phase
% input, since it won't be phase getting sent
phases(phases < 0) = phases(phases < 0) + 360;
phases(phases >= 360) = phases(phases >= 360) - 360;
phaseSteps = round(phases/1.4);


% XXX: for now need to send the increment as 1/8 step sizes, so need to
% convert from the step value selected to 1/8
% TODO: need to handle step value properly on arduino side and then remove
% this conversion
%measIncInt = measInc * bitshift(1, stepValue);

% convert angle to microangle for sending
measIncInt = measInc * 1e6;


% handle the different command options
switch (cmd)
    case 'start'
        fprintf('sending start cmd...\n');
        fwrite(s, CMD_START, 'uint8');  % command type
        fwrite(s, axisValue, 'uint8');  % axis parameter
        fwrite(s, nmeas, 'uint8');      % number of measurements per step
        
    case 'stop'
        fprintf('sending stop cmd...\n');
        fwrite(s, CMD_STOP, 'uint8');  % command type
        
    case 'pause'
        fprintf('sending pause cmd...\n');
        fwrite(s, CMD_PAUSE, 'uint8');  % command type
        
    case 'zero'
        fprintf('sending zero cmd...\n');
        fwrite(s, CMD_ZERO, 'uint8');  % command type
        fwrite(s, axisValue, 'uint8'); % axis parameter
        
    case 'reset'
        fprintf('sending reset cmd...\n');
        fwrite(s, CMD_RESET, 'uint8');  % command type
        fwrite(s, axisValue, 'uint8');  % axis parameter
        
    case 'move'
        fprintf('sending move cmd...\n');
        fwrite(s, CMD_MOVE, 'uint8');  % command type
        fwrite(s, axisValue, 'uint8');  % axis parameter
        fwrite(s, dirValue, 'uint8');  % direction parameter
        fwrite(s, numSteps, 'uint8');  % number of steps to move
        
    case 'configure'
        fprintf('sending configure cmd...\n');
        fwrite(s, CMD_CONFIGURE, 'uint8');  % command type
        fwrite(s, axisValue, 'uint8');      % axis parameter
        fwrite(s, stepValue, 'uint8');      % step size parameter
        fwrite(s, measIncInt, 'int32');    % measurement increment (as micro angle)
        fwrite(s, startAngle, 'int32');     % start angle in microdegrees
        fwrite(s, endAngle, 'int32');       % end angle in microdegrees
    
    case 'moveto'
        fprintf('sending move to cmd...\n');
        fwrite(s, CMD_MOVE_TO, 'uint8');
        fwrite(s, axisValue, 'uint8');
        fwrite(s, startAngle, 'int32');
    
    case 'setphase'
        fprintf('sending phase cmd...\n');
        fwrite(s, CMD_SET_PHASE, 'uint8');
        fwrite(s, phaseSteps(1), 'uint8');
        fwrite(s, phaseSteps(2), 'uint8');
        fwrite(s, phaseSteps(3), 'uint8');
        
        
    otherwise
        error('Invalid Command');
end

