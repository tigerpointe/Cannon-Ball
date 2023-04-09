<#

.SYNOPSIS
Starts a new Cannon Ball Arcade game in PowerShell.

.DESCRIPTION
Implements a classic arcade-style "shooter" game in PowerShell.

The text animation blinks. If you are sensitive to light, do not play.

This script CANNOT be started from the IDE because keypress detection is used.

This script MUST be started from a real PowerShell console window.

Characters:
  ^      : cannon (moved by a player along the bottom of the screen)
  .      : cannon ball (only one can be launched upward at a time)
  / or \ : moving targets (each moves across and downward towards the cannon)
  |      : falling torpedo (must be avoided and cannot be stopped)

Control Keys:
  Q           : Quit the game
  P           : Pause the game (press any other key to un-pause)
  Left Arrow  : Move the cannon to the left
  Right Arrow : Move the cannon to the right
  Down Arrow  : Stop the cannon movement
  Space Bar   : Launch the cannon ball at a target

Every hit on a target scores one point.

The game ends when the cannon collides with a target or torpedo.

Please consider giving to cancer research.

.PARAMETER sleep
Specifies a sleep value for the pause between each screen refresh.
(milliseconds)

.INPUTS
None.

.OUTPUTS
A whole lot of fun.

.EXAMPLE
.\Start-CannonBall.ps1
Starts the program with the default options.

.EXAMPLE
.\Start-CannonBall.ps1 -sleep 55
Starts the program with a lower sleep value (for faster play).

.EXAMPLE
.\Start-CannonBall.ps1 -sleep 85
Starts the program with a higher sleep value (for slower play).

.NOTES
MIT License

Copyright (c) 2023 TigerPointe Software, LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

If you enjoy this software, please do something kind for free.

The screen data is composed of a hash table of rows based on the height.
Each row is composed of a character array of spaces based on the width.
Game characters are added to replace the spaces using X and Y coordinates.
On each loop, the console is reset, and every text row is over-written.

The nay-sayers said that a game like this was impossible, but here it is.

History:
01.00 2023-Apr-09 Scott S. Initial release.

.LINK
https://braintumor.org/

.LINK
https://www.cancer.org/

#>
#Requires -Version 5.1
param
(

  # Defines a default sleep value for the pause between each screen refresh
  [string]$sleep = 75

)

try
{

  # Define the text escape sequence to reset the cursor position to 0,0
  # (can be used as an alternative to Clear-Host on some systems)
  $escape = "$([char]27)[H"; # code 27 = ESC

  # Define the control keys
  # (script cannot be started from the IDE, keypress requires a true console)
  [ConsoleKey]$quit   = [ConsoleKey]::Q;          # quit
  [ConsoleKey]$pause  = [ConsoleKey]::P;          # pause
  [ConsoleKey]$left   = [ConsoleKey]::LeftArrow;  # move left
  [ConsoleKey]$right  = [ConsoleKey]::RightArrow; # move right
  [ConsoleKey]$stop   = [ConsoleKey]::DownArrow;  # stop
  [ConsoleKey]$button = [ConsoleKey]::Spacebar;   # launch ball

  # Loop while more games are selected
  $more = "Y";
  while ($more -eq "Y")
  {

    # Initialize the screen properties
    $screen        = @{};
    $screen.Height = 16;
    $screen.Width  = 25;
    $screen.Score  = 0;
    $screen.Sleep  = $sleep; # milliseconds between loops
    $screen.Data   = @{};    # empty hash table for screen data
    $screen.Border = ("-" * $screen.Width);

    # Initialize the cannon properties
    $cannon      = @{};
    $cannon.Icon = "^";
    $cannon.X    = [Math]::Ceiling($screen.Width / 2);
    $cannon.Y    = ($screen.Height - 1);

    # Initialize the ball properties
    $ball         = @{};
    $ball.Icon    = ".";
    $ball.X       = 0;
    $ball.Y       = 0;
    $ball.Visible = $false;

    # Initialize the torpedo properties
    $torpedo         = @{};
    $torpedo.Icon    = "|";
    $torpedo.X       = 0;
    $torpedo.Y       = 0;
    $torpedo.Chance  = 3; # percentage chance of appearance
    $torpedo.Visible = $false;

    # Initialize the targets collection
    $spacing = 3;
    $count   = [Math]::Floor($screen.Width / $spacing);
    $targets = @{};
    for ($i = 0; $i -lt $count; $i++)
    {
      $targets[$i]         = @{};
      $targets[$i].Icon    = "\";
      $targets[$i].IconAlt = "/";
      $targets[$i].Toggle  = $true;
      $targets[$i].X       = ($i * $spacing);
      $targets[$i].Y       = 0;
      $targets[$i].Step    = 1;
      $targets[$i].Splat   = "*";
      $targets[$i].Hit     = $false;
      $targets[$i].Minimum = ($spacing - 1); # hit minimum distance
    }

    # Hide the cursor (otherwise, the cursor flashes)
    [Console]::CursorVisible = $false;

    # Pause briefly before starting the game
    Clear-Host;
    Write-HOst -Object "`nCANNON BALL ARCADE";
    Write-HOst -Object "`nControl Keys:`n";
    Write-HOst -Object " Q            Quit";
    Write-HOst -Object " P            Pause";
    Write-HOst -Object " Left Arrow   Move Left";
    Write-HOst -Object " Right Arrow  Move Right";
    Write-HOst -Object " Down Arrow   Stop";
    Write-HOst -Object " Space Bar    Launch Ball";
    Write-Host -Object "`nPress ANY Key to Begin";

    # Loop while the game is running
    $keypress = $pause;
    $running  = $true;
    while ($running)
    {

      # Clear the screen data (creates a hash table of character arrays)
      for ($row = 0; $row -lt $screen.Height; $row++)
      {
        $screen.Data[$row] = (" " * $screen.Width).ToCharArray();
      }

      # Read the next keypress
      if ([Console]::KeyAvailable)         # non-blocking
      {
        $read = [Console]::ReadKey($true); # true = do not echo key value
        $keypress = $read.Key;
      }

      # Check the keypress value
      if ($keypress -eq $quit)
      {

        # Stop the running loop
        $running = $false;
        continue;

      }
      elseif ($keypress -eq $pause)
      {

        # Sleep and continue to loop without rendering the screen data
        Start-Sleep -Milliseconds $screen.Sleep;
        continue;

      }
      elseif (($keypress -eq $right) -and `
              ($cannon.X -lt ($screen.Width - 1)))
      {

        # Move the cannon right
        $cannon.X++;

      }
      elseif (($keypress -eq $left) -and `
              ($cannon.X -gt 0))
      {

        # Move the cannon left
        $cannon.X--;

      }
      elseif (($keypress -eq $button) -and `
              (-not $ball.Visible))
      {

        # Launch a new ball (one at a time only)
        $ball.X       = $cannon.X;
        $ball.Y       = $cannon.Y;
        $ball.Visible = $true;
        $keypress     = $stop;

      }

      # Add the cannon to the screen data
      $screen.Data[$cannon.Y][$cannon.X] = $cannon.Icon;

      # Add the ball to the screen data
      if ($ball.Visible)
      {

        # Move the ball upward
        $ball.Y--;
        $screen.Data[$ball.Y][$ball.X] = $ball.Icon;

      }

      # Add the torpedo to the screen data
      if ($torpedo.Visible)
      {

        # Move the torpedo downward
        $torpedo.Y++;
        $screen.Data[$torpedo.Y][$torpedo.X] = $torpedo.Icon;

      }
      else
      {

        # Otherwise, randomly initialize a new torpedo
        $torpedo.Y = 0;
        $chance = (Get-Random -Maximum 100);
        if ($chance -le $torpedo.Chance)
        {
          $torpedo.X = $Cannon.X;
          $torpedo.Visible = $true;
        }

      }

      # Add each target to the screen data
      for ($i = 0; $i -lt $count; $i++)
      {

        # Check for a ball hit within the minimum distance
        if ($ball.Visible)
        {
          $diffX = [Math]::Abs($ball.X - $targets[$i].X);
          if (($diffX -lt $targets[$i].Minimum) -and `
              ($ball.Y -eq $targets[$i].Y))
          {
            $screen.Score++;
            $ball.Visible = $false;
            $targets[$i].Hit = $true;
          }
        }

        # Toggle alternates between the two icons, unless hit
        $icon = $targets[$i].Icon;
        $targets[$i].Toggle = (-not $targets[$i].Toggle);
        if ($targets[$i].Toggle) { $icon = $targets[$i].IconAlt; }
        if ($targets[$i].Hit)    { $icon = $targets[$i].Splat;   }
        $screen.Data[$targets[$i].Y][$targets[$i].X] = $icon;

        # Move the target
        if ($targets[$i].Hit)
        {

          # Reset the target position after a hit
          $targets[$i].X    = 0;
          $targets[$i].Y    = 0;
          $targets[$i].Step = 1;
          $targets[$i].Hit  = $false;

        }
        else
        {

          # Step value controls the target forward and backward movement
          $targets[$i].X = ($targets[$i].X + $targets[$i].Step);
          if ($targets[$i].X -ge ($screen.Width - 1))
          {
            $targets[$i].Step = -1; # move left
            $targets[$i].Y++;       # move down
          }
          elseif ($targets[$i].X -le 0)
          {
            $targets[$i].Step = 1;  # move right
            $targets[$i].Y++;       # move down
          }

        }

      } # end for-target

      # Append all screen data into a buffer for faster rendering
      $sb = [System.Text.StringBuilder]::new();
      $score = "HITS:  $($screen.Score.ToString("N0"))";
      [void]$sb.AppendLine($score.PadRight($screen.Width));
      [void]$sb.AppendLine($screen.Border);
      for ($row = 0; $row -lt $screen.Height; $row++)
      {
        [void]$sb.AppendLine($screen.Data[$row] -join "");
      }
      $buffer = $sb.ToString(); # double-buffering

      # Write the completed buffer to the console (Clear-Host flashes)
      Write-Host -Object $escape; # set position to 0,0 without clearing
      Write-Host -Object $buffer; # over-write screen data in one step

      # Boundary check for misses
      if ($ball.Y -eq 0) { $ball.Visible = $false; }
      if ($torpedo.Y -eq ($screen.Height - 1)) { $torpedo.Visible = $false; }

      # End the game on a collision with a torpedo
      if (($cannon.X -eq $torpedo.X) -and `
          ($cannon.Y -eq $torpedo.Y))
      {
        $running = $false;
        continue;
      }

      # End the game on a collision with a target
      for ($i = 0; $i -lt $count; $i++)
      {
        $diffX = [Math]::Abs($cannon.X - $targets[$i].X);
        if (($diffX -lt $targets[$i].Minimum) -and `
            ($cannon.Y -eq $targets[$i].Y))
        {
          $running = $false;
          continue;
        }
      }

      # Sleep to slow the running loop
      Start-Sleep -Milliseconds $screen.Sleep;

    } # end while-running

    # Prompt for another game
    $more = "";
    [Console]::CursorVisible = $true;
    while (($more.Length -ne 1) -or (-not ("YN").Contains($more)))
    {
      $more = Read-Host -Prompt "`nGAME OVER - Play again? (Y/N)";
      $more = $more.Trim().ToUpper();
    }

  } # end while-more

}
catch
{
  Write-Error $_;
}