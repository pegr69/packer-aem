#!/bin/bash 

AMI_ROLE_ARR=("Base AMI" "Java AMI" "AEM Author AMI" "AEM Publish AMI" "Apache HTTP Server AMI" "AEM Dispatcher AMI")

for (( i=0; i < ${#AMI_ROLE_ARR[@]}; i++)); do
  echo "processing images for application role \"${AMI_ROLE_ARR[$i]}\" .... "

  OLD_AMIS=$(aws ec2 describe-images --owner self \
         --filters "Name=tag:Application Id,Values=Adobe Experience Manager (AEM)"\
                    "Name=tag:Application Role,Values=${AMI_ROLE_ARR[$i]}" \
         --region ap-southeast-2 | jq -r '."Images"|sort_by(."CreationDate")|.[0:-3]|.[]."ImageId"')

  for OLD_AMI in $OLD_AMIS; do
    LCG_COUNT=$(aws autoscaling describe-launch-configurations \
               --query 'LaunchConfigurations[?ImageId==`'"$OLD_AMI"'`].LaunchConfigurationName'| jq 'length')
    if [ "$LCG_COUNT" -gt 0 ]; then
      echo "Not deregistering image $OLD_AMI because it is still used by some launch configurations"
      continue
    fi
    RUNNING_COUNT=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
                   --query 'Reservations[].Instances[?ImageId==`'"$OLD_AMI"'`].InstanceId' | jq 'flatten|length')
    if [ "$RUNNING_COUNT" -gt 0 ]; then
      echo "Not deregistering image $OLD_AMI becuase it is still used by some runningn instances"
      continue
    fi
    echo -n "Deregistering staled image $OLD_AMI ...."
    aws ec2 deregister-image --image-id "$OLD_AMI" --region ap-southeast-2
    sleep 1
    echo "Done"
  done
done
