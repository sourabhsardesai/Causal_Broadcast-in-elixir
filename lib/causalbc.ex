defmodule CausalBC do



  def start(name,participant_list) do
    pid = spawn( CausalBC,:process, [decleration(name,participant_list)])          # a process is spawn  by the name of "process" and the initial variables are passed inside the process
     case :global.register_name(name,pid) do    # global.register registers the name of participant with the pid
       :yes -> pid                                 # if yes then the respective pid is returned
       :no  -> :error                                # if no respective error is returned
    end

  end


  def process(current_status) do
   # IO.puts("#{current_status.participant_label}: " <> inspect(current_status.ts))       #Inspects the given argument according to the Inspect protocol. The second argument is a keyword list with options to control inspection.
    current_status = receive do


      {:input,:broadcast_begin,msg} ->
        current_status = update_in(current_status,[:ts,current_status.participant_label],  &(&1 + 1) )       # Updates a key in a nested structure update_in(data, keys, fun)

           for part <- List.delete(current_status.participant_list,current_status.participant_label) do   # removes the sender from the participants list in order to avoid sending data to itself
            pid = :global.whereis_name(part)       # returns the pid of the process

            if( current_status.participant_label ) do    # checks wether the name of the sender exisits
           :timer.sleep(2000)                                 # waits for 2 seconds
             end
             temp_current_status = current_status.ts                                                      # Load the current_status in temp_current_status variable
           send(pid,{:bc_msg,msg,temp_current_status,current_status.participant_label})     # sends the message to all the participants which are added to the list
           end

        current_status






        {:output, :bc_rcvd,msg,origin} ->                                 # takes the message sent from the participant  and displays on the console
          IO.puts("Message delivered at: #{inspect current_status.participant_label} Incoming Broadcast -  #{msg} from #{inspect origin}")
          current_status


          {:bc_msg,msg,t,origin} ->
            current_status = update_in(current_status, [:message_tobesent], fn(list) -> [{msg,t,origin} | list] end)  # update the pending message to the list
                           end

        messages = remove_message_tobesent(current_status,(current_status.message_tobesent))####
        current_status = %{ current_status | message_tobesent: current_status.message_tobesent -- messages }




         if messages != [] do                                      # if the message box is not empty get inside
          for {msg,_,origin} <- messages do
            send(self(),{:output,:bc_rcvd,msg,origin})               # send the pending message to process
          end
        end



        process(current_status)
  end


  defp remove_message_tobesent(_,[]), do: []
  defp refresh([],current_status), do: current_status
  defp refresh([{m,t,xi} | messages],current_status) do                            # update functions to make sure the updated message is sent
     current_status = update_in(current_status,[:ts,xi],fn(t) -> t+1 end)
     refresh(messages,current_status)
  end
  ##########

  defp remove_message_tobesent(current_status,[{msg,t,xi} | rest]) do
    if(Map.get(t,xi) == current_status.ts[xi]+1) do
      auth = for part <- current_status.participant_list , part != xi do ####
          Map.get(t,part)<= current_status.ts[part]
      end
      if (Enum.member?(auth,true)) do
        [{msg,t,xi} | remove_message_tobesent(current_status,rest)]
      else
        remove_message_tobesent(current_status,rest)
      end
    end
  end

  #####################


  def bc_send(msg,origin) do                                      # send function used by the sender participant to bradcast the message
    send(origin,{:input,:broadcast_begin,msg})                    # sends the message to the process with its sender as origin and rest of the message in msg
  end
  ############################


  defp decleration(name,participant_list) do                # mapping of variables which are used in rest of the program
    %{ participant_label: name,
       message_tobesent: [],
       participant_list: participant_list,
       ts: for part <- participant_list, into: %{} do
                {part,0}
           end
     }
  end
end
